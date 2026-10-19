locals {
  account_id = data.aws_caller_identity.this.account_id

  # Sufijo de cuenta para los nombres que tienen que ser unicos en todo AWS
  suffix = local.account_id

  tags = {
    Project   = var.project
    ManagedBy = "terraform"
  }

  # Nombres de los buckets, unicos globalmente
  bucket_front = format("%s-frontend-%s", var.project, local.suffix)
  bucket_media = format("%s-media-%s", var.project, local.suffix)

  # Catalogos de seed, un archivo JSON por tipo cargado como items
  # { "CATEGORIA#0001" = {...}, "ZONA#0001" = {...}, ... }
  seed_items = merge([
    for tipo in ["categoria", "zona", "urgencia"] : {
      for item in jsondecode(file("${path.module}/seed/${tipo}.json")) :
      "${upper(tipo)}#${format("%04d", item.id)}" => merge(item, { tipo = tipo })
    }
  ]...)

  front_origin = var.front_origin != "" ? var.front_origin : "http://${local.bucket_front}.s3-website-${var.region}.amazonaws.com"

  # Content-Type por extension para los archivos del front subidos a S3
  content_types = {
    html = "text/html"
    css  = "text/css"
    js   = "application/javascript"
    json = "application/json"
    svg  = "image/svg+xml"
    png  = "image/png"
    jpg  = "image/jpeg"
    ico  = "image/x-icon"
    map  = "application/json"
    txt  = "text/plain"
  }

  # Prefijo del dominio de la Hosted UI, unico globalmente
  cognito_domain_prefix = "${var.project}-${local.suffix}"

  # Lambdas de API que ya existen, cada una con sus rutas. Agregar un dominio es
  # sumar una entrada aca y su carpeta en back/functions/
  api_functions = {
    catalogos = {
      routes = ["GET /api/categorias", "GET /api/zonas", "GET /api/urgencias"]
      public = true
    }
    usuarios = {
      routes = ["GET /api/auth/me", "POST /api/auth/registro"]
      public = false
    }
    solicitudes = {
      routes = [
        "GET /api/solicitudes",
        "POST /api/solicitudes",
        "GET /api/trabajos",
        "GET /api/solicitudes/{id}",
        "GET /api/solicitudes/{id}/seguimiento",
      ]
      public = false
    }
    fotos = {
      routes = [
        "POST /api/solicitudes/{id}/fotos",
        "GET /api/solicitudes/{id}/fotos",
      ]
      public = false
    }
    flujo = {
      routes = [
        "POST /api/solicitudes/{id}/aceptar",
        "POST /api/solicitudes/{id}/iniciar",
        "POST /api/solicitudes/{id}/resolver",
        "POST /api/solicitudes/{id}/liberar",
        "POST /api/solicitudes/{id}/cancelar",
      ]
      public = false
    }
    calificaciones = {
      routes = [
        "POST /api/solicitudes/{id}/calificacion",
        "GET /api/solicitudes/{id}/calificacion",
      ]
      public = false
    }
  }

  # Aplana api_functions en un mapa ruta -> {fn, public} para el for_each de las rutas
  api_routes = merge([
    for fn, cfg in local.api_functions : {
      for ruta in cfg.routes : ruta => { fn = fn, public = cfg.public }
    }
  ]...)

  # Mock data, usuarios de demo. nombre -> datos del perfil
  demo_users = {
    "cliente.demo" = {
      email      = "cliente.demo@example.com"
      nombre     = "Maria"
      apellido   = "Cliente"
      telefono   = "1150000001"
      rol        = "CLIENTE"
      categorias = []
    }
    "plomero.demo" = {
      email      = "plomero.demo@example.com"
      nombre     = "Pedro"
      apellido   = "Plomero"
      telefono   = "1150000002"
      rol        = "PROFESIONAL"
      categorias = [1]
    }
    "electricista.demo" = {
      email      = "electricista.demo@example.com"
      nombre     = "Elena"
      apellido   = "Electricista"
      telefono   = "1150000003"
      rol        = "PROFESIONAL"
      categorias = [2]
    }
  }
}
