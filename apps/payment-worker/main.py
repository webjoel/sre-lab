"""payment-worker: consome eventos de pedido criado e simula o processamento do pagamento."""

import json
import logging
import os
import random
import signal
import sys
import threading
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import pika
import pika.exceptions
import psycopg

# Topologia da fila: deve ser idêntica à declarada pela order-api (nomes e argumentos).
ORDERS_EXCHANGE = "orders"
ORDERS_QUEUE = "orders.created"
ORDERS_ROUTING_KEY = "order.created"
DLX_EXCHANGE = "orders.dlx"
DEAD_QUEUE = "orders.dead"

DATABASE_URL = os.getenv(
    "DATABASE_URL", "postgresql://pedidos:pedidos@localhost:5432/pedidos"
)
AMQP_URL = os.getenv("AMQP_URL", "amqp://pedidos:pedidos@localhost:5672/%2F")
FAIL_RATE = float(os.getenv("FAIL_RATE", "0.05"))
PROCESSING_MS_MIN = int(os.getenv("PROCESSING_MS_MIN", "50"))
PROCESSING_MS_MAX = int(os.getenv("PROCESSING_MS_MAX", "300"))
PREFETCH = int(os.getenv("PREFETCH", "10"))
HEALTH_PORT = int(os.getenv("HEALTH_PORT", "8081"))

log = logging.getLogger("payment-worker")
state = {"consuming": False}


class JsonFormatter(logging.Formatter):
    """Logs estruturados em JSON, no mesmo estilo da order-api."""

    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "time": self.formatTime(record, "%Y-%m-%dT%H:%M:%S%z"),
            "level": record.levelname,
            "msg": record.getMessage(),
        }
        payload.update(getattr(record, "fields", {}))
        if record.exc_info:
            payload["exc"] = self.formatException(record.exc_info)
        return json.dumps(payload, ensure_ascii=False)


def setup_logging() -> None:
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JsonFormatter())
    logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"), handlers=[handler])
    logging.getLogger("pika").setLevel(logging.WARNING)


class HealthHandler(BaseHTTPRequestHandler):
    """/healthz responde 200 enquanto o worker estiver consumindo a fila."""

    def do_GET(self) -> None:  # nome exigido pela biblioteca padrão
        if self.path != "/healthz":
            self.send_response(404)
            self.end_headers()
            return
        ok = state["consuming"]
        self.send_response(200 if ok else 503)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps({"consuming": ok}).encode())

    def log_message(self, *args) -> None:
        pass  # evita poluir o log com cada health check


def start_health_server() -> None:
    server = ThreadingHTTPServer(("0.0.0.0", HEALTH_PORT), HealthHandler)
    threading.Thread(target=server.serve_forever, daemon=True).start()


def connect_with_retry(connect, what: str, attempts: int = 15, wait: float = 2.0):
    for attempt in range(1, attempts + 1):
        try:
            return connect()
        except Exception as exc:  # noqa: BLE001
            log.warning(
                "tentativa de conexão falhou",
                extra={
                    "fields": {
                        "dependencia": what,
                        "tentativa": attempt,
                        "err": str(exc),
                    }
                },
            )
            time.sleep(wait)
    raise RuntimeError(f"não foi possível conectar em {what}")


def declare_topology(channel) -> None:
    channel.exchange_declare(
        exchange=ORDERS_EXCHANGE, exchange_type="direct", durable=True
    )
    channel.exchange_declare(
        exchange=DLX_EXCHANGE, exchange_type="fanout", durable=True
    )
    channel.queue_declare(queue=DEAD_QUEUE, durable=True)
    channel.queue_bind(queue=DEAD_QUEUE, exchange=DLX_EXCHANGE, routing_key="")
    channel.queue_declare(
        queue=ORDERS_QUEUE,
        durable=True,
        arguments={"x-dead-letter-exchange": DLX_EXCHANGE},
    )
    channel.queue_bind(
        queue=ORDERS_QUEUE, exchange=ORDERS_EXCHANGE, routing_key=ORDERS_ROUTING_KEY
    )


def make_handler(db):
    def on_message(channel, method, properties, body) -> None:
        # Valida tudo antes de tocar no banco. Uma exceção não tratada aqui derruba o processo
        # sem ack, a mensagem volta para a fila e derruba o próximo pod: loop de poison message.
        # Ex.: {"order_id": "abc"} faria o UPDATE lançar psycopg.DataError (uuid inválido).
        try:
            event = json.loads(body)
            order_id = str(uuid.UUID(event["order_id"]))
        except (ValueError, KeyError, TypeError, AttributeError):
            log.error(
                "mensagem inválida enviada para a DLQ",
                extra={"fields": {"body": body[:200].decode(errors="replace")}},
            )
            channel.basic_nack(delivery_tag=method.delivery_tag, requeue=False)
            return

        start = time.monotonic()
        time.sleep(random.uniform(PROCESSING_MS_MIN, PROCESSING_MS_MAX) / 1000)

        if random.random() < FAIL_RATE:
            # Simula falha de processamento (ex.: timeout do gateway). A mensagem vai para a DLQ
            # e o pedido fica PENDING: é o sinal que o alerta de "pedidos presos" vai capturar.
            log.warning(
                "falha ao processar pagamento; mensagem enviada para a DLQ",
                extra={"fields": {"order_id": order_id}},
            )
            channel.basic_nack(delivery_tag=method.delivery_tag, requeue=False)
            return

        # Idempotente: reprocessar a mesma mensagem não altera um pedido já pago.
        with db.cursor() as cur:
            cur.execute(
                "UPDATE orders SET status = 'PAID', updated_at = now() WHERE id = %s AND status = 'PENDING'",
                (order_id,),
            )
            updated = cur.rowcount

        channel.basic_ack(delivery_tag=method.delivery_tag)
        log.info(
            "pagamento processado"
            if updated
            else "pedido já processado ou inexistente (idempotência)",
            extra={
                "fields": {
                    "order_id": order_id,
                    "duration_ms": round((time.monotonic() - start) * 1000),
                }
            },
        )

    return on_message


def main() -> int:
    setup_logging()
    start_health_server()

    db = connect_with_retry(
        lambda: psycopg.connect(DATABASE_URL, autocommit=True), "postgres"
    )
    params = pika.URLParameters(AMQP_URL)
    params.heartbeat = 30
    connection = connect_with_retry(lambda: pika.BlockingConnection(params), "rabbitmq")
    channel = connection.channel()
    declare_topology(channel)
    channel.basic_qos(prefetch_count=PREFETCH)
    channel.basic_consume(queue=ORDERS_QUEUE, on_message_callback=make_handler(db))

    def shutdown(signum, _frame) -> None:
        log.info("sinal de encerramento recebido", extra={"fields": {"signal": signum}})
        connection.add_callback_threadsafe(channel.stop_consuming)

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)

    log.info(
        "payment-worker iniciado",
        extra={"fields": {"fail_rate": FAIL_RATE, "prefetch": PREFETCH}},
    )
    state["consuming"] = True
    try:
        channel.start_consuming()
    except (psycopg.OperationalError, pika.exceptions.AMQPError):
        # Design crash-only: sem reconexão elaborada; mensagens sem ack voltam para a fila
        # e o orquestrador reinicia o processo.
        log.exception("dependência indisponível; encerrando")
        return 1
    finally:
        state["consuming"] = False

    connection.close()
    db.close()
    log.info("payment-worker encerrado")
    return 0


if __name__ == "__main__":
    sys.exit(main())
