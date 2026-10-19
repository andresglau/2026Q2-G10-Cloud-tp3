# BarrioFix, arquitectura e infraestructura


## Recursos

| Servicio | Uso en BarrioFix |
|---|---|
| AWS Lambda | Ejecuta el backend, una función por dominio más dos funciones por evento |
| Amazon API Gateway (HTTP API) | Entrada HTTPS a las Lambdas, con authorizer de Cognito y throttling |
| Amazon DynamoDB | Datos de la aplicación, en una tabla única con tres GSIs |
| Amazon Cognito | Registro y login por Hosted UI, emisión de tokens |
| AWS Secrets Manager | Guarda el client secret del app client de Cognito |
| Amazon S3 | Sitio estático del frontend, fotos (media) y state de Terraform |
| Amazon VPC con Gateway Endpoints | Red de las Lambdas, salida privada a DynamoDB y S3 |
| AWS IAM (LabRole) | Rol de ejecución de las Lambdas |
| Amazon CloudWatch Logs | Logs de las Lambdas |
| AWS Shield Standard | Protección L3/L4, activa por defecto en API Gateway y S3 |

## Cómo se comunican

El frontend es un sitio estático en S3. Al arrancar lee un `config.json` que Terraform
sube con la URL de la API y los datos de Cognito, así el mismo build sirve para cualquier
cuenta.

Para entrar, el navegador redirige a la Hosted UI de Cognito. Cognito vuelve a
`GET /callback` en API Gateway, que invoca a la Lambda `auth-callback`. Esa función canjea
el código de autorización por los tokens (se autentica contra Cognito con el client secret
que lee de Secrets Manager) y redirige al frontend con los tokens en el fragment de la URL.
El sitio es HTTP y la Hosted UI exige que el callback sea HTTPS, por eso el callback vive en
API Gateway y no en el propio sitio.

Ya con el token, el navegador llama a la API. API Gateway valida el token con el authorizer
de Cognito antes de invocar nada y aplica throttling. Cada ruta va a la Lambda de su dominio
(catálogos, usuarios, solicitudes, flujo, calificaciones, fotos). Cognito solo autentica,
quién es cada uno. La autorización, el rol de cliente o profesional, vive en DynamoDB, y el
registro se completa en dos pasos: la cuenta se crea en la Hosted UI y el perfil (nombre,
rol, categorías) se carga con una llamada a la API la primera vez que el usuario entra.

Las Lambdas leen y escriben en DynamoDB, y las fotos van aparte: el backend firma una URL y
el navegador sube o baja el archivo directo a S3, sin pasar por API Gateway ni por la Lambda.

## Funciones por evento

Además de las Lambdas de la API, hay dos que no se invocan por HTTP sino por un evento de
otro servicio.

- `cognito-pre-signup`, la invoca Cognito en cada alta antes de crear la cuenta. La usamos
  para autoconfirmar los usuarios sin mandar un mail de verificación, que simplifica la demo.
- `foto-subida`, la invoca S3 cuando termina de subir una foto al bucket de media. Registra
  la foto en la solicitud correspondiente. Es idempotente, si S3 reintenta el evento no la
  duplica.

## Datos

La tabla es única, con clave de partición PK y clave de orden SK, y tres GSIs sparse.
`por_cliente` trae las solicitudes de un cliente, `por_profesional` las asignadas a un
profesional y `pendientes` los trabajos disponibles por categoría. El estado de cada
solicitud se guarda en el propio ítem (desnormalizado) y se mantiene con transacciones.
Que dos profesionales no tomen el mismo trabajo se resuelve con escrituras condicionales
sobre el estado, no con bloqueos.

Los catálogos (categorías, zonas y urgencias) y los usuarios de demo se cargan como seed
desde Terraform.

## Red

Las Lambdas que tocan datos viven en subredes privadas, sin NAT ni Internet Gateway, y solo
alcanzan DynamoDB y S3 por Gateway Endpoints, que son gratis. Las endpoint policies de esos
endpoints acotan el acceso a la tabla y al bucket exactos del proyecto, así una función
comprometida no tiene a dónde sacar datos. La excepción es `auth-callback`, que va fuera de
la VPC porque llama al endpoint de Cognito por internet, y a cambio no toca los datos del
sistema.

Con RDS en el TP2 había un tier aparte de subredes de base de datos. Al pasar a DynamoDB,
que es un servicio regional y no vive en la VPC, ese tier desaparece y queda un solo tier de
subredes privadas de aplicación.

## Seguridad

Como `LabRole` es amplio y fijo y en el Learner Lab no se pueden crear roles, el mínimo
privilegio no se expresa con políticas de identidad finas sino por otros medios. La red lo
aplica con las endpoint policies de los Gateway Endpoints. Los recursos lo aplican con la
bucket policy del front, una resource policy opcional de DynamoDB que solo acepta tráfico
desde el endpoint de la VPC, y los `aws_lambda_permission` que limitan quién invoca cada
función.

El client secret de Cognito está en Secrets Manager, lo lee `auth-callback` en runtime. Las
fotos usan URLs prefirmadas con condiciones (tamaño máximo, solo imágenes, key exacta). Los
endpoints que no se pueden autenticar, el callback y los catálogos públicos, se protegen con
el throttling de API Gateway y con la concurrencia reservada de `auth-callback`, para que un
flood no agote el límite de concurrencia de la cuenta. DynamoDB y S3 cifran en reposo por
defecto y todo el tráfico externo es HTTPS.

No incorporamos WAF. Solo se puede asociar a una REST API o a CloudFront, no a una HTTP API,
y CloudFront no está disponible en el lab, así que usarlo obligaría a pasar la API a REST API
sin un beneficio claro en una API sin SQL ni render de HTML. Queda anotado como mejora futura.

Algunas cosas que marca el análisis estático (el tfsec del template y el code scanning de GitHub)
quedan así a propósito. El bucket del frontend es público, porque sirve el sitio estático, con una
bucket policy que solo permite GetObject y nada de escrituras ni listado. El costo es que no tiene
HTTPS directo (por eso el callback de Cognito pasa por API Gateway) ni CDN adelante. El versionado
de ese bucket está apagado porque el sitio se reconstruye entero en cada deploy y las versiones
viejas del build no aportan.

El cifrado en reposo usa las llaves gestionadas por AWS en lugar de CMK propias en DynamoDB,
Secrets Manager, S3 y los log groups de CloudWatch. El análisis estático pide CMK, pero en el
Learner Lab no creamos llaves KMS propias, por costo y porque LabRole no es para eso. Las Lambdas
tienen tracing de X-Ray activado. No activamos point in time recovery en DynamoDB ni el access
logging de API Gateway, que para esta entrega no justifican su costo y complejidad frente a lo que
ya aportan los logs de las Lambdas.

El detalle de Terraform (módulos, funciones, meta-argumentos y state) está en el README.
