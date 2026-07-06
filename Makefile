# Azure AKS Runtime Security — one-command deploy / harden / attack / destroy.
.PHONY: help deploy credentials falco kyverno policy-test runtime-attack destroy

TF := terraform -chdir=terraform
RG := rg-aks-runtime-sec
CLUSTER := aks-runtime-security

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

deploy: ## terraform init + apply the AKS cluster and Defender for Containers
	$(TF) init
	$(TF) apply -auto-approve

credentials: ## Fetch kubeconfig for the lab cluster
	az aks get-credentials --resource-group $(RG) --name $(CLUSTER) --overwrite-existing

falco: ## Install Falco runtime detection
	bash k8s/falco/install.sh

kyverno: ## Install Kyverno and apply the admission policies
	bash k8s/kyverno/install.sh

policy-test: ## Run the Kyverno policy unit tests (no cluster needed)
	kyverno test k8s/kyverno/tests/

runtime-attack: ## Run the runtime attack scenarios against Falco and Kyverno
	bash k8s/attack-scenarios/run-runtime-attacks.sh

destroy: ## Tear down the cluster and resource group
	$(TF) destroy -auto-approve
