variable "region" {
  description = "Region de AWS donde se despliega toda la infra"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Prefijo de nombres y tag comun de todos los recursos"
  type        = string
  default     = "barriofix"
}

variable "vpc_cidr" {
  description = "Bloque CIDR de la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Letras de las Availability Zones a usar (se anteponen a la region)"
  type        = list(string)
  default     = ["a", "b"]
}

variable "lab_role_name" {
  description = "Rol de instancia o servicio preexistente del Learner Lab"
  type        = string
  default     = "LabRole"
}

variable "powertools_layer_arn" {
  description = "ARN del layer publico de AWS Lambda Powertools (Python 3.12, x86_64)"
  type        = string
  default     = "arn:aws:lambda:us-east-1:017000801446:layer:AWSLambdaPowertoolsPythonV3-python312-x86_64:39"
}

variable "restrict_dynamodb_to_vpc" {
  description = "Si es true, agrega una resource policy que solo permite acceso a DynamoDB desde el endpoint de la VPC. Apagarlo para poder mirar la tabla desde la consola"
  type        = bool
  default     = false
}

variable "demo_password" {
  description = "Contraseña de los usuarios de demo (mock data). Es ficticia"
  type        = string
  default     = "BarrioFix-Demo-2026!"
  sensitive   = true
}

variable "front_origin" {
  description = "Origen del frontend permitido en CORS. Si queda vacio, se usa la URL del bucket website"
  type        = string
  default     = ""
}

variable "lambda_memory" {
  description = "Memoria (MB) de las Lambdas de API"
  type        = number
  default     = 1024
}

variable "lambda_timeout" {
  description = "Timeout (s) de las Lambdas de API"
  type        = number
  default     = 15
}

variable "api_throttle_rate" {
  description = "Requests por segundo sostenidas por stage en API Gateway"
  type        = number
  default     = 50
}

variable "api_throttle_burst" {
  description = "Rafaga maxima de requests en API Gateway"
  type        = number
  default     = 100
}

variable "front_dist_path" {
  description = "Ruta al dist/ ya compilado del front. Vacio = no subir archivos (solo config.json)."
  type        = string
  default     = ""
}

variable "auth_callback_reserved_concurrency" {
  description = "Concurrencia reservada de auth-callback (tope ante floods al endpoint publico)"
  type        = number
  default     = 10
}
