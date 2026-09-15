variable "cluster_name" {
  description = "Nome do cluster kind"
  type        = string
  default     = "sre-lab"
}

variable "worker_count" {
  description = "Quantidade de nós worker. Com 16 GiB de RAM, 1 é o recomendado."
  type        = number
  default     = 1

  validation {
    condition     = var.worker_count >= 0 && var.worker_count <= 3
    error_message = "Use entre 0 e 3 workers."
  }
}

variable "node_image" {
  description = "Imagem kindest/node. Vazio usa a padrão do provider. Fixe uma versão para reprodutibilidade."
  type        = string
  default     = ""
}
