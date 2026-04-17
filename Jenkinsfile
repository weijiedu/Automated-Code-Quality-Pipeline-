pipeline {
  agent any

  tools {
    'hudson.plugins.sonar.SonarRunnerInstallation' 'sonar-scanner'
  }

  environment {
    SONAR_HOST_URL = 'http://sonarqube-service.default.svc.cluster.local:9000'
  }

  stages {
    stage('Checkout') {
      steps {
        git branch: 'main',
            url: 'https://github.com/xinshu-cmu-S25/mayavi'
      }
    }

    stage('Wait for SonarQube') {
      steps {
        sh '''
          for i in $(seq 1 60); do
            resp=$(curl -s ${SONAR_HOST_URL}/api/system/status || true)
            echo "$resp"
            echo "$resp" | grep -q '"status":"UP"' && exit 0
            sleep 3
          done
          echo "SonarQube not UP in time" >&2
          exit 1
        '''
      }
    }

    stage('SonarQube Analysis') {
      steps {
        script {
          def scannerHome = tool name: 'sonar-scanner', type: 'hudson.plugins.sonar.SonarRunnerInstallation'

          withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
            withEnv(["SCANNER_HOME=${scannerHome}"]) {
              sh '''
                set -eu

                echo "Sanity check SonarQube auth..."
                curl -s -o /dev/null -w "HTTP %{http_code}\n" \
                  -u "${SONAR_TOKEN}:" \
                  ${SONAR_HOST_URL}/api/v2/analysis/version

                echo "Running sonar-scanner from $SCANNER_HOME ..."
                "$SCANNER_HOME/bin/sonar-scanner" \
                  -Dsonar.projectKey=mayavi \
                  -Dsonar.sources=. \
                  -Dsonar.host.url=${SONAR_HOST_URL} \
                  -Dsonar.token=${SONAR_TOKEN}
              '''
            }
          }
        }
      }
    }

    stage('Check for Blockers') {
      steps {
        script {
          withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
            sh '''
              set -eu
              echo "Waiting for SonarQube analysis to finish processing..."
              for i in $(seq 1 60); do
                resp=$(curl -s -u "${SONAR_TOKEN}:" \
                  "${SONAR_HOST_URL}/api/ce/component?component=mayavi")
                status=$(echo "$resp" | sed -n 's/.*"current":{[^}]*"status":"\\([^"]*\\)".*/\\1/p')
                if [ -z "$status" ]; then
                  status="NONE"
                fi
                echo "  CE task status: $status"
                if [ "$status" = "SUCCESS" ]; then
                  break
                elif [ "$status" = "FAILED" ] || [ "$status" = "CANCELED" ]; then
                  echo "SonarQube analysis task failed!" >&2
                  exit 1
                fi
                sleep 5
              done
            '''

            def blockerCount = sh(
              script: '''
                curl -s -u "${SONAR_TOKEN}:" \
                  "${SONAR_HOST_URL}/api/issues/search?componentKeys=mayavi&severities=BLOCKER&statuses=OPEN,CONFIRMED,REOPENED&ps=1" \
                  | sed -n 's/.*"total":\\([0-9]*\\).*/\\1/p'
              ''',
              returnStdout: true
            ).trim().toInteger()

            if (blockerCount > 0) {
              echo "Found ${blockerCount} BLOCKER issue(s). Skipping Hadoop job."
              env.HAS_BLOCKERS = 'true'
            } else {
              echo "No BLOCKER issues found. Proceeding to Hadoop job."
              env.HAS_BLOCKERS = 'false'
            }
          }
        }
      }
    }

    stage('Run Hadoop Job') {
      when {
        expression { env.HAS_BLOCKERS != 'true' }
      }
      steps {
        sh '''
          set -eu

          # Install gcloud CLI (bundled with Python) if not already present
          BUNDLED_PY=$(find /tmp/google-cloud-sdk/platform/bundledpythonunix -name "python3" 2>/dev/null | head -1)
          if [ -z "$BUNDLED_PY" ]; then
            echo "Installing Google Cloud CLI with bundled Python..."
            rm -rf /tmp/google-cloud-sdk
            curl -sSL https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz \
              -o /tmp/gcloud-cli.tar.gz
            tar -xzf /tmp/gcloud-cli.tar.gz -C /tmp
            rm /tmp/gcloud-cli.tar.gz
            BUNDLED_PY=$(find /tmp/google-cloud-sdk/platform/bundledpythonunix -name "python3" 2>/dev/null | head -1)
          fi
          export PATH=/tmp/google-cloud-sdk/bin:$PATH
          if [ -n "$BUNDLED_PY" ]; then
            export CLOUDSDK_PYTHON="$BUNDLED_PY"
          fi

          gcloud config set project "$GCP_PROJECT_ID"

          echo "Uploading repository to GCS..."
          gsutil -m rsync -r -x '\\.git/' . "gs://${GCS_BUCKET}/mayavi_src/"

          # Clean previous output if it exists
          gsutil -m rm -r "gs://${GCS_BUCKET}/mayavi_output/" 2>/dev/null || true

          echo "Submitting Hadoop Streaming job..."
          gcloud dataproc jobs submit hadoop \
            --cluster="$HADOOP_CLUSTER" \
            --region="$HADOOP_REGION" \
            --class=org.apache.hadoop.streaming.HadoopStreaming \
            --properties="mapreduce.input.fileinputformat.input.dir.recursive=true,mapreduce.job.reduces=1" \
            -- \
            -files "gs://${GCS_BUCKET}/mayavi_src/mr/mapper.py,gs://${GCS_BUCKET}/mayavi_src/mr/reducer.py" \
            -mapper "python3 mapper.py" \
            -reducer "python3 reducer.py" \
            -input "gs://${GCS_BUCKET}/mayavi_src/" \
            -output "gs://${GCS_BUCKET}/mayavi_output/"

          echo "=========================================="
          echo "   Hadoop MapReduce Line Count Results"
          echo "=========================================="
          gsutil cat "gs://${GCS_BUCKET}/mayavi_output/part-*"
        '''
      }
    }
  }
}
