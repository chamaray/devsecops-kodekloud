pipeline {
  agent any

  stages {

    stage('Build & Test') {
      steps {
        sh "mvn clean verify"
      }
      post {
        always {
          // JUnit Reports
          junit 'target/surefire-reports/*.xml'

          // JaCoCo Coverage
          jacoco execPattern: 'target/jacoco.exec'
        }
      }
    }

    stage('Archive Artifact') {
      steps {
        archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
      }
    }
    stage('Docker Build and Push'){
      steps (
        sh 'print.env'
        sh 'docker build -t chamaray/numeric-app:"$GIT_COMMIT"'
        sh 'docker push chamaray/numeric-app:"$GIT_COMMIT"'
      )
    }
    

  }
}
