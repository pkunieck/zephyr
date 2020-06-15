properties([disableConcurrentBuilds()])
node('jfsotc17') {
    deleteDir()
    withEnv(["HTTP_PROXY=http://proxy-chain.intel.com:911",
             "HTTPS_PROXY=http://proxy-chain.intel.com:911",
             "http_proxy=http://proxy-chain.intel.com:911",
             "https_proxy=http://proxy-chain.intel.com:911",
             "no_proxy=localhost,proxy-chain.intel.com:911"]) {
		checkout scm
		stage("docker build") {
			sh "docker build --build-arg HTTPPROXY=$http_proxy --build-arg HTTPSPROXY=$https_proxy --build-arg NOPROXY=$no_proxy -t  amr-registry.caas.intel.com/zephyrproject/sdk-docker-intel:staging ."
		}
//cv: disabling push to registry while testing
//		stage("docker tag and push") {
//			withCredentials([usernamePassword(credentialsId: '7a961c1f-23a6-492b-8007-6773737ca144', passwordVariable: 'REGISTRYPASS', usernameVariable: 'REGISTRYUSER')]) {
//				sh "docker login -u $REGISTRYUSER -p $REGISTRYPASS amr-registry.caas.intel.com"
//			}
//			sh "docker push amr-registry.caas.intel.com/zephyrproject/sdk-docker-intel:staging"
//			sh "docker logout amr-registry.caas.intel.com"
//		}
	}//env
}//node

