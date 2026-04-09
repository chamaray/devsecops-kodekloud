pipeline {
  agent any

  environment {
    IMAGE_NAME = "chamaray/numeric-app"
  }

  stages {

    stage('Build & Unit Test') {
      agent {
        docker {
          image 'maven:3.9.6-eclipse-temurin-17'
        }
      }
      steps {
        sh "mvn clean verify"
        stash includes: 'target/*.jar', name: 'app-jar'
      }
      post {
        always {
          junit 'target/surefire-reports/*.xml'
          jacoco execPattern: 'target/jacoco.exec'
        }
      }
    }

    stage('SonarQube - SAST') {
      agent {
        docker {
          image 'maven:3.9.6-eclipse-temurin-17'
        }
      }
      steps {
        withSonarQubeEnv('SonarQube') {
          sh """
          mvn sonar:sonar \
          -Dsonar.projectKey=numeric-application \
          -Dsonar.projectName=numeric-application
          """
        }
      }
    }

    stage('Quality Gate') {
      steps {
        timeout(time: 2, unit: 'MINUTES') {
          waitForQualityGate abortPipeline: true
        }
      }
    }

    stage('Mutation Testing (PIT)') {
      agent {
        docker {
          image 'maven:3.9.6-eclipse-temurin-17'
        }
      }
      steps {
        sh "mvn org.pitest:pitest-maven:mutationCoverage"
      }
      post {
        always {
          archiveArtifacts artifacts: 'target/pit-reports/**'
        }
      }
    }

    stage('Archive Artifact') {
      steps {
        unstash 'app-jar'
        archiveArtifacts artifacts: 'target/*.jar'
      }
    }

    stage('Docker Build & Push') {
      steps {
        unstash 'app-jar'
        withDockerRegistry([credentialsId: "docker-hub", url: ""]) {
          sh """
          docker build -t ${IMAGE_NAME}:${GIT_COMMIT} .
          docker push ${IMAGE_NAME}:${GIT_COMMIT}
          """
        }
      }
    }

    stage('Deploy to Kubernetes') {
      steps {
        withKubeConfig([credentialsId: 'kubeconfig']) {
          sh """
          sed -i 's#replace#${IMAGE_NAME}:${GIT_COMMIT}#g' k8s_deployment_service.yaml
          kubectl apply -f k8s_deployment_service.yaml
          """
        }
      }
    }
    stage('Vulnerability Scan - Docker'){
      steps{
        parallel{
          "Dependency Scan" :{
            sh "mvn dependency-check:check"
          },
            "Trivy Scan":{
              sh "bash trivy-docker-image-scan.sh"
            }
        }
      }
    }
  }

  post {
    success { echo "✅ Pipeline executed successfully!" }
    failure { echo "❌ Pipeline failed. Check logs." }
  }
}
