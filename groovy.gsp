pipeline {
    agent any
    
    stages {
        stage('Git') {
            steps {
                checkout([$class: 'GitSCM', branches: [[name: '*/master']], doGenerateSubmoduleConfigurations: false, extensions: [], submoduleCfg: [], userRemoteConfigs: [[credentialsId: '4155498f-ceab-4c96-9472-15fbf05f350a', url: 'https://github.com/mmonk33/groovy-pipe.git']]])
            }
        }
        stage('Build') {
            steps {
                sh 'docker run --name docker-nginx -p 9889:80 -d -v /var/lib/jenkins/workspace/sf_pipe/:/usr/share/nginx/html nginx'
            }
        }
       stage('Check HTTP response code') {
           steps {
               script{
                    cmd = """
                          curl --write-out %{http_code} --silent --output /dev/null \
                          'http://localhost:9889' 
                          """
                    status_code = sh(script: cmd, returnStdout: true).trim()
                    if (status_code != "200") {
                        sh 'curl -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" -d "chat_id=${CHAT_ID}&text=URL status different of 200"'
                        error('URL status different of 200.')
                     } 
                }
            }
        }

       stage('Check md5sum') {
           steps {
               script{
                    cmd = '''
                         md5sum  /var/lib/jenkins/workspace/sf_pipe/index.html |  awk '{print $1}'
                          '''
                    md_sum = sh(script: cmd, returnStdout: true).trim()
                    cmd = '''
                        docker exec docker-nginx  md5sum  /usr/share/nginx/html/index.html | awk '{print $1}'
                          '''
                    md_sum_ni = sh(script: cmd, returnStdout: true).trim()          
                    echo "Check md5sum nginx file index.html: ${md_sum_ni}"
                    
                    if (md_sum != md_sum_ni) {  
                        sh 'curl -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" -d "chat_id=${CHAT_ID}&text=different md5sum hash"'
                        error('different md5sum hash')
      } 
    }
  }
}
       stage('Cleanup') {
           steps {
               echo 'Cleaning..'
               sh 'docker stop docker-nginx && docker rm docker-nginx'
            }
        }
  }
}