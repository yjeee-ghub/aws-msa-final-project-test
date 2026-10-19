# 리소스 이름에 사용할 프로젝트 이름
variable "project_name" {
  type = string
}

# 이미지 업로드를 허용할 ECR 저장소 ARN 목록
variable "ecr_repository_arns" {
  type = list(string)
}

# 이 저장소의 main 브랜치에서 발급한 인증 정보만 허용
# 개인 저장소 main의 OIDC sub claim을 루트 변수에서 전달합니다.
variable "github_oidc_subject" {
  type = string

  description = "실제 GitHub OIDC subject. 원 작성자의 계정/저장소 ID를 재사용하지 않습니다."
}
