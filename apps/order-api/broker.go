package main

import (
	"context"
	"encoding/json"
	"errors"
	"sync"
	"time"

	amqp "github.com/rabbitmq/amqp091-go"
)

// Topologia da fila. O payment-worker declara exatamente os mesmos nomes e argumentos.
const (
	ordersExchange   = "orders"
	ordersQueue      = "orders.created"
	ordersRoutingKey = "order.created"
	dlxExchange      = "orders.dlx"
	deadQueue        = "orders.dead"
)

type OrderCreated struct {
	OrderID     string `json:"order_id"`
	AmountCents int64  `json:"amount_cents"`
	Currency    string `json:"currency"`
}

type Broker struct {
	conn   *amqp.Connection
	ch     *amqp.Channel
	mu     sync.Mutex
	closed chan *amqp.Error
}

func connectBroker(ctx context.Context, url string) (*Broker, error) {
	var conn *amqp.Connection
	err := retry(ctx, 15, 2*time.Second, "rabbitmq", func() error {
		c, err := amqp.Dial(url)
		if err != nil {
			return err
		}
		conn = c
		return nil
	})
	if err != nil {
		return nil, err
	}

	ch, err := conn.Channel()
	if err != nil {
		conn.Close()
		return nil, err
	}
	if err := declareTopology(ch); err != nil {
		conn.Close()
		return nil, err
	}
	// Publisher confirms: o broker confirma que recebeu cada mensagem.
	if err := ch.Confirm(false); err != nil {
		conn.Close()
		return nil, err
	}

	return &Broker{
		conn:   conn,
		ch:     ch,
		closed: conn.NotifyClose(make(chan *amqp.Error, 1)),
	}, nil
}

func declareTopology(ch *amqp.Channel) error {
	if err := ch.ExchangeDeclare(ordersExchange, "direct", true, false, false, false, nil); err != nil {
		return err
	}
	if err := ch.ExchangeDeclare(dlxExchange, "fanout", true, false, false, false, nil); err != nil {
		return err
	}
	if _, err := ch.QueueDeclare(deadQueue, true, false, false, false, nil); err != nil {
		return err
	}
	if err := ch.QueueBind(deadQueue, "", dlxExchange, false, nil); err != nil {
		return err
	}
	args := amqp.Table{"x-dead-letter-exchange": dlxExchange}
	if _, err := ch.QueueDeclare(ordersQueue, true, false, false, false, args); err != nil {
		return err
	}
	return ch.QueueBind(ordersQueue, ordersRoutingKey, ordersExchange, false, nil)
}

func (b *Broker) PublishOrderCreated(ctx context.Context, evt OrderCreated) error {
	body, err := json.Marshal(evt)
	if err != nil {
		return err
	}

	b.mu.Lock()
	confirm, err := b.ch.PublishWithDeferredConfirmWithContext(ctx, ordersExchange, ordersRoutingKey, false, false,
		amqp.Publishing{
			ContentType:  "application/json",
			DeliveryMode: amqp.Persistent,
			MessageId:    evt.OrderID,
			Timestamp:    time.Now(),
			Body:         body,
		})
	b.mu.Unlock()
	if err != nil {
		return err
	}

	ok, err := confirm.WaitContext(ctx)
	if err != nil {
		return err
	}
	if !ok {
		return errors.New("broker recusou a mensagem (nack)")
	}
	return nil
}

func (b *Broker) IsOpen() bool { return !b.conn.IsClosed() }

func (b *Broker) Closed() <-chan *amqp.Error { return b.closed }

func (b *Broker) Close() {
	_ = b.ch.Close()
	_ = b.conn.Close()
}
