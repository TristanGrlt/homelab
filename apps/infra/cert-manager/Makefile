include common.mk
K8S_NS = cert-manager
K8S_RELEASE = cert-manager

## --------------------------------------
##@ Apply
## --------------------------------------
apply: ## apply manifests to ${K8S_CONTEXT}
apply: yamls
	kubectl -n ${K8S_NS} apply -R -f yamls

## --------------------------------------
##@ Delete
## --------------------------------------
delete: ## delete manifests to ${K8S_CONTEXT}
delete: yamls
	kubectl -n ${K8S_NS} delete -R -f yamls

## --------------------------------------
##@ Manifests
## --------------------------------------
manifests: ## build k8s manifests
manifests: yamls
yamls: dependencies cert-manager

cert-manager: dependencies
	helm template --include-crds -n ${K8S_NS} ${K8S_RELEASE} . -f values.${@}.yaml -f <(sops -d enc.$@.values.yaml) --output-dir yamls

## --------------------------------------
##@ Dependencies
## --------------------------------------
dependencies: ## Build helm dependencies
dependencies: Chart.lock charts

Chart.lock:
	helm dependency build

charts:
	helm dependency build

## --------------------------------------
##@ Clean
## --------------------------------------
clean: ## Remove helm dependencies and yamls manifests
clean:
	rm -rf yamls Chart.lock charts
