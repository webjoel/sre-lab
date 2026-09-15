terraform {
  required_version = ">= 1.6"

  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.8"
    }
  }

  # Fase 0: state local. Na Fase 3 este state migra para um bucket S3 no LocalStack.
}
