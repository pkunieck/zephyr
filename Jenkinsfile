properties([disableConcurrentBuilds()])
node('testhead-jf') {
    deleteDir()
    withEnv(["HTTP_PROXY=http://proxy-chain.intel.com:911",
             "HTTPS_PROXY=http://proxy-chain.intel.com:911",
             "http_proxy=http://proxy-chain.intel.com:911",
             "https_proxy=http://proxy-chain.intel.com:911",
             "no_proxy=localhost,proxy-chain.intel.com:911"]) {
		checkout scm
		stage("docker build") {
			//chmod 777 entrypoint to allow non-root users to access, required on PRD VMs - likely from home dir flags/permissions
			sh "chmod 777 entrypoint.sh"
			sh "docker build --build-arg HTTPPROXY=$http_proxy --build-arg HTTPSPROXY=$https_proxy --build-arg NOPROXY=$no_proxy --build-arg UID=\$(id -u) --build-arg GID=\$(id -g) -t 127.0.0.1:5000/sdk-docker-intel:master ."
		}
		stage("docker push") {
			sh "docker push 127.0.0.1:5000/sdk-docker-intel:master"

//			withCredentials([usernamePassword(credentialsId: '7a961c1f-23a6-492b-8007-6773737ca144', passwordVariable: 'REGISTRYPASS', usernameVariable: 'REGISTRYUSER')]) {
//				sh "docker login -u $REGISTRYUSER -p $REGISTRYPASS amr-registry.caas.intel.com"
//			}
//			sh "docker push amr-registry.caas.intel.com/zephyrproject/sdk-docker-intel:staging"
//			sh "docker logout amr-registry.caas.intel.com"

		}
	}//env
}//node

