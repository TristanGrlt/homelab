# Kanidm Identity Provider (OIDC)

This directory contains the declarative deployment and configuration of **Kanidm**, an identity management server used as the OpenID Connect (OIDC) provider for cluster services and infrastructure applications.

## Overview & Stack

To ensure full declarative reconciliation and lightweight resource consumption, the identity stack relies on the following components:

- **Kanidm**: A modern identity management server written in Rust. It provides OIDC authentication, role-based group mapping, and native support for Passkeys (WebAuthn) and TOTP multi-factor authentication, backed by an embedded SQLite database.
- **Kaniop (`kaniop.rs/v1beta1`):** A Kubernetes operator written in Rust that manages the lifecycle of Kanidm instances and continuously reconciles identity resources (`Kanidm`, `KanidmPersonAccount`, `KanidmGroup`, `KanidmOAuth2Client`) from Kubernetes Custom Resource Definitions (CRDs).
- **cert-manager:** Provisions the internal TLS certificate required by the Kanidm server pod.
- **Kubernetes Gateway API (Traefik):** Exposes the HTTPS endpoint externally via an `HTTPRoute` and enforces end-to-end TLS encryption to the backend pod using a `BackendTLSPolicy`.

## Chart Architecture

This deployment is structured as an **umbrella Helm chart**. It embeds the upstream `kaniop` operator chart as an OCI dependency while defining custom templates to instantiate the identity server and its resources from a single values file.

```text
.
├── Chart.yaml                  # Declares the upstream kaniop OCI dependency
├── values.yaml                 # Centralized configuration (domain, TLS, gateway, users, groups, OIDC clients)
└── templates/
    ├── ca-configmap.yaml       # Publishes the CA certificate bundle for backend TLS validation
    ├── certificate.yaml        # cert-manager Certificate for the Kanidm pod
    ├── instance.yaml           # Kanidm CRD defining the StatefulSet, storage, and replica group
    ├── httproute.yaml          # Gateway API HTTPRoute and BackendTLSPolicy
    ├── users.yaml              # Declarative KanidmPersonAccount resources
    ├── groups.yaml             # Declarative KanidmGroup resources
    └── oauth2-clients.yaml     # Declarative KanidmOAuth2Client resources
```

### Deployment Ordering (Sync Waves)

Because Custom Resources cannot be applied before the operator registers its CRDs in the Kubernetes API, resources are ordered using ArgoCD sync waves:

1. **Wave `0`:** Installs the `kaniop` operator, registers the `kaniop.rs` CRDs, and creates the `cert-manager` `Certificate` and CA `ConfigMap`.
2. **Wave `1`:** Deploys the `Kanidm` instance (`auth`) along with all `KanidmPersonAccount`, `KanidmGroup`, and `KanidmOAuth2Client` resources.
3. **Wave `2`:** Applies the `HTTPRoute` and `BackendTLSPolicy` once the backend `Service` created by the operator is available.

### End-to-End TLS Routing

Kanidm enforces HTTPS on its internal listener (`port 8443`) and does not accept unencrypted HTTP traffic. Traffic flows as follows:

1. External clients connect over HTTPS to the Gateway (`internal-gateway`), which terminates the external TLS session.
2. Traefik re-encrypts traffic to the Kanidm backend service (`auth:8443`).
3. The `BackendTLSPolicy` instructs Traefik to validate the pod certificate against the root CA stored in the `homelab-ca-bundle` ConfigMap.

## Configuration

All identity objects are managed declaratively in `values.yaml`. Updating this file and committing changes triggers automatic reconciliation through ArgoCD and Kaniop:

* **Users (`users`):** Creates `KanidmPersonAccount` entries without storing passwords in Git.
* **Groups (`groups`):** Creates `KanidmGroup` entries and enforces exact membership lists. Removing a user from a group in `values.yaml` automatically revokes their group membership in Kanidm.
* **OIDC Clients (`oauth2Clients`):** Creates `KanidmOAuth2Client` resources and maps group scopes (`openid`, `profile`, `email`, `groups`). For each client, Kaniop automatically generates a Kubernetes `Secret` in the target namespace containing the generated `client_secret`.

## Operations & User Onboarding

### Retrieve Initial Admin Credentials

Kaniop generates initial credentials for the built-in `admin` (system configuration) and `idm_admin` (identity and access management) service accounts in a Kubernetes `Secret` within the `kanidm` namespace:

```bash
kubectl get secrets -n kanidm
kubectl get secret -n kanidm <admin-secret-name> -o jsonpath='{.data}'
```

### Generate a User Onboarding Link

New users are created without credentials. To allow a user to set their own password and enroll MFA (Passkey or TOTP), generate a single-use credential reset URL using the `kanidm` CLI:

```bash
# Authenticate as idm_admin
kanidm login -H https://auth.home.grltt.fr -D idm_admin

# Generate a one-time onboarding link 
kanidm person credential create-reset-token -H https://auth.home.grltt.fr <username>
```

Send the resulting `https://auth.home.grltt.fr/ui/reset?token=...` URL to the user to complete their account setup.

### Verify Reconciliation Status

Check the health and readiness of all managed Kanidm resources:

```bash
kubectl get kanidm,kanidmpersonaccount,kanidmgroup,kanidmoauth2client -A
```
