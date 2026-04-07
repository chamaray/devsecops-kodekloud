pipeline {
  agent any

  stages {

    stage('Build & Test') {
      steps {
        sh "mvn clean verify"
      }
      post {
        always {
          junit 'target/surefire-reports/*.xml'
          jacoco execPattern: 'target/jacoco.exec'
        }
      }
    }

    stage('Archive Artifact') {
      steps {
        archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
      }
    }

    stage('Docker Build and Push') {
      steps {
        withDockerRegistry([credentialsId: "docker-hub", url: ""]) {
          
          sh 'printenv'

          sh "docker build -t chamaray/numeric-app:${GIT_COMMIT} ."

          sh "docker push chamaray/numeric-app:${GIT_COMMIT}"
        }
      }
    }

stage('Kubernetes Deployment - DEV') {
      steps {
        withKubeConfig([credentialsId: 'kubeconfig']){
          sh "sed -i 's#replace#chamaray/numeric-app:${GIT_COMMIT}#g' k8s_deployment_service.yaml"
          sh "kubectl apply -f k8s_deployment_service.yaml"
        }
      }
    }


    
  }
}
