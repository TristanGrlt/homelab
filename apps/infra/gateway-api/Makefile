include common.mk
K8S_CONTEXT = ${USER}-bare-pq1-cluster
K8S_NS = kube-system
K8S_RELEASE = gateway-api

## --------------------------------------
##@ Apply
## --------------------------------------
apply: ## apply manifests to ${K8S_CONTEXT}
apply: yamls
	kubectl --context ${K8S_CONTEXT} -n ${K8S_NS} apply -R -f yamls

## --------------------------------------
##@ Delete
## --------------------------------------
delete: ## delete manifests to ${K8S_CONTEXT}
delete: yamls
	kubectl --context ${K8S_CONTEXT} -n ${K8S_NS} delete -R -f yamls

## --------------------------------------
##@ Manifests
## --------------------------------------
manifests: ## build k8s manifests
manifests: yamls
yamls: gateway-api

gateway-api:
	helm template --include-crds -n ${K8S_NS} ${K8S_RELEASE} . --output-dir yamls

## --------------------------------------
##@ Clean
## --------------------------------------
clean: ## Remove yamls manifests
clean:
	rm -rf yamls
