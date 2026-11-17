pipeline {
  agent any
  options {
    timeout(time: 75, unit: 'MINUTES')
    disableConcurrentBuilds()
    timestamps()
  }
  triggers { pollSCM('H/2 * * * *') }
  environment {
    REGISTRY = '342278407001.dkr.ecr.us-east-1.amazonaws.com'
    AWS_DEFAULT_REGION = 'us-east-1'
  }
  stages {
    stage('Prepare') {
      steps {
        script {
          env.TAG = sh(returnStdout: true, script: 'git rev-parse --short=8 HEAD').trim()
          def author = sh(returnStdout: true, script: 'git log -1 --pretty=%an').trim()
          env.BOT = (author == 'jenkins-ci') ? 'true' : 'false'
          currentBuild.description = (env.BOT == 'true') ? 'skipped: values bump by CI' : "image tag ${env.TAG}"
        }
      }
    }
    stage('Validate Helm chart') {
      when { environment name: 'BOT', value: 'false' }
      steps {
        sh '''
          for v in values-minikube.yaml values-eks.yaml; do
            docker run --rm -v "$PWD":/w -w /w alpine/helm:3.16.3 lint helm/faraja -f helm/faraja/$v
          done
          docker run --rm -v "$PWD":/w -w /w alpine/helm:3.16.3 template faraja helm/faraja -f helm/faraja/values-eks.yaml \
            | docker run --rm -i ghcr.io/yannh/kubeconform:latest -strict -ignore-missing-schemas -summary -
        '''
      }
    }
    stage('Registry login') {
      when { environment name: 'BOT', value: 'false' }
      steps {
        withCredentials([usernamePassword(credentialsId: 'aws-ecr', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          sh '''
            docker run --privileged --rm tonistiigi/binfmt --install amd64
            aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $REGISTRY
          '''
        }
      }
    }
    stage('Backend image') {
      when { environment name: 'BOT', value: 'false' }
      steps {
        retry(3) { sh 'docker buildx build --platform linux/amd64 -t $REGISTRY/faraja-backend:$TAG -t $REGISTRY/faraja-backend:latest --push ./backend' }
      }
    }
    stage('Frontend image') {
      when { environment name: 'BOT', value: 'false' }
      steps {
        retry(3) { sh 'docker buildx build --platform linux/amd64 --build-arg NEXT_PUBLIC_API_BASE_URL=/api -t $REGISTRY/faraja-frontend:$TAG -t $REGISTRY/faraja-frontend:latest --push ./frontend' }
      }
    }
    stage('Deploy via GitOps') {
      when { environment name: 'BOT', value: 'false' }
      steps {
        withCredentials([usernamePassword(credentialsId: 'github-token', usernameVariable: 'GH_USER', passwordVariable: 'GH_TOKEN')]) {
          sh '''
            sed -i -E "/^backend:/,/^frontend:/ s/^(    tag: ).*/\\1$TAG/" helm/faraja/values-eks.yaml
            sed -i -E "/^frontend:/,\\$ s/^(    tag: ).*/\\1$TAG/" helm/faraja/values-eks.yaml
            git config user.name jenkins-ci
            git config user.email jenkins-ci@faraja.local
            git add helm/faraja/values-eks.yaml
            git diff --cached --quiet || git commit -m "ci: deploy $TAG"
            git push https://$GH_USER:$GH_TOKEN@github.com/Abdirahman-Maalim/faraja.git HEAD:eks-deployment
          '''
        }
      }
    }
  }
  post {
    failure {
      mail to: "${env.ALERT_EMAIL}",
           subject: "FAILED: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
           body: "Build failed.\nCommit: ${env.TAG}\nDetails: ${env.BUILD_URL}"
    }
    fixed {
      mail to: "${env.ALERT_EMAIL}",
           subject: "RECOVERED: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
           body: "Build is passing again.\nDetails: ${env.BUILD_URL}"
    }
    always { sh 'docker logout $REGISTRY || true' }
  }}
