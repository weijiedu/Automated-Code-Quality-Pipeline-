module "ci" {
  source = "./ci"

  project_id = var.project_id
  region     = var.region
  zone       = var.zone
}

module "hadoop" {
  source = "./hadoop"

  project_id = var.project_id
  region     = var.region
  zone       = var.zone
}
