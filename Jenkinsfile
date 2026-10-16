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
          currentBuild.description = (env.BOT == 'true') ? 'skipped: manifest bump by CI' : "image tag ${env.TAG}"
        }
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
            sed -i -E "s#(faraja-backend):[A-Za-z0-9._-]+#\\1:$TAG#" k8s/backend-deployment.yaml
            sed -i -E "s#(faraja-frontend):[A-Za-z0-9._-]+#\\1:$TAG#" k8s/frontend-deployment.yaml
            git config user.name jenkins-ci
            git config user.email jenkins-ci@faraja.local
            git add k8s/backend-deployment.yaml k8s/frontend-deployment.yaml
            git diff --cached --quiet || git commit -m "ci: deploy $TAG"
            git push https://$GH_USER:$GH_TOKEN@github.com/Abdirahman-Maalim/faraja.git HEAD:eks-deployment
          '''
        }
      }
    }
  }
  post {
    always { sh 'docker logout $REGISTRY || true' }
  }
}
