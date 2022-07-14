


########### DO NOT EDIT #############################
# To update call: make add-generated-help-block
# This is added to help document dynamic targets and support shell autocompletion


##@ GIT/Repo Targets
clone-repo:  ## Clone upstream `emissary`
checkout-repo: ## Checkout upstream tag based on value in GIT_TAG file

##@ Binary Targets
binaries: ## Build all binaries: `emissary` for `linux/amd64 linux/arm64`
_output/bin/emissary/linux-amd64/emissary: ## Build `_output/bin/emissary/linux-amd64/emissary`
_output/bin/emissary/linux-arm64/emissary: ## Build `_output/bin/emissary/linux-arm64/emissary`

# ##@ Image Targets
local-images: ## Builds `emissary/images/amd64` as oci tars for presumbit validation
images: ## Pushes `emissary/images/push` to IMAGE_REPO
emissary/images/amd64: ## Builds/pushes `emissary/images/amd64`
emissary/images/push: ## Builds/pushes `emissary/images/push`

##@ Helm Targets
helm/pull: ## Pulls the upstream helm chart
helm/build: ## Build helm chart
helm/push: ## Build helm chart and push to registry defined in IMAGE_REPO.

##@ Checksum Targets
checksums: ## Update checksums file based on currently built binaries.
validate-checksums: # Validate checksums of currently built binaries against checksums file.

##@ License Targets
gather-licenses: ## Helper to call $(GATHER_LICENSES_TARGETS) which gathers all licenses
attribution: ## Generates attribution from licenses gathered during `gather-licenses`.
attribution-pr: ## Generates PR to update attribution files for projects

##@ Clean Targets
clean: ## Removes source and _output directory
clean-repo: ## Removes source directory

##@ Helpers
help: ## Display this help
add-generated-help-block: ## Add or update generated help block to document project make file and support shell auto completion

# ##@Update Helpers
# run-target-in-docker: ## Run `MAKE_TARGET` using builder base docker container
# update-attribution-checksums-docker: ## Update attribution and checksums using the builder base docker container
# stop-docker-builder: ## Clean up builder base docker container
# generate: ## Update UPSTREAM_PROJECTS.yaml
# create-ecr-repos: ## Create repos in ECR for project images for local testing

##@ Build Targets
build: ## Called via prow presubmit, calls `handle-dependencies validate-checksums attribution local-images  attribution-pr`
release: ## Called via prow postsubmit + release jobs, calls `handle-dependencies validate-checksums images `
########### END GENERATED ###########################
