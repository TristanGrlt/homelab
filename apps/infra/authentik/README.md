# Authentik

This directory deploys and configures [Authentik](https://goauthentik.io/).
Authentik is an open-source identity provider (IdP). It stores users and
groups, authenticates people, and can later provide single sign-on (SSO) to
services through protocols such as OAuth2/OIDC, SAML, and proxy
authentication.

The goal of this deployment is to keep the installation and the important
configuration in Git. Argo CD deploys the Kubernetes resources, Helm deploys
Authentik and PostgreSQL, and Authentik Blueprints configure Authentik itself.

## How this directory works

The repository uses an **umbrella Helm chart**:

```text
apps/infra/apps/authentik.yaml       # Argo CD Application
apps/infra/authentik/Chart.yaml      # Local umbrella chart
apps/infra/authentik/values.authentik.yaml
apps/infra/authentik/templates/      # Additional Kubernetes resources
apps/infra/authentik/blueprints/     # Authentik configuration
apps/infra/authentik/scripts/        # Operational helper scripts
```

## Blueprints

An Authentik **Blueprint** is a YAML file describing Authentik objects such as:

- flows;
- stages;
- groups;
- users;
- providers;
- policies;
- applications.

Blueprints are configuration for Authentik's database. They are different from
Kubernetes manifests:

- Argo CD reconciles Kubernetes resources directly.
- Authentik reads Blueprints and reconciles the described Authentik objects.
- `state: present` creates an object if needed and updates the fields declared
  in `attrs`.
- `state: created` creates an object but does not keep updating it.
- `state: absent` deletes an object.
- Removing an entry from a Blueprint does not automatically delete the old
  Authentik object. Use `state: absent` when deletion is intended.

Blueprint files are stored in:

```text
apps/infra/authentik/blueprints/
```

Authentik discovers
the files and applies them. Blueprint files should have stable names, for
example:

```text
010-groups.yaml
020-enrollment.yaml
030-login-flow.yaml
040-providers.yaml
```

The numeric prefix documents the intended dependency order. When objects in
different Blueprints depend on each other, prefer keeping them in one
Blueprint or use Authentik's Blueprint dependency mechanisms.

## Invitation enrollment

`blueprints/010-invitation-enrollment.yaml` defines three enrollment flows:

| Role | Flow slug | Group | Authentik administration |
| --- | --- | --- | --- |
| Admin | `homelab-enrollment-admin` | `homelab-admins` | Superuser |
| Operator | `homelab-enrollment-operator` | `homelab-operators` | No admin permission by default |
| User | `homelab-enrollment-user` | `homelab-users` | No admin permission |

The group determines the initial classification of the account. A group does
not automatically grant application access or Authentik administration unless
permissions or bindings are configured for that group.

Each flow contains these stages:

```text
Invitation
    ↓
Username, password, password confirmation
    ↓
Name and email
    ↓
Create the user
    ↓
Add the user to the role group
    ↓
Log the user in
```

The invited person chooses their own username and password.

### Creating an invitation link

The helper script creates invitations through the Authentik API. It does not
modify Git or create a Blueprint.

Requirements:

- `curl`;
- `jq`;
- an Authentik API token with permission to create invitations;
- network access to Authentik.

From this directory, set the API URL and token:

```bash
export AUTHENTIK_URL=https://authentik.home.grltt.fr
export AUTHENTIK_TOKEN='keep-this-out-of-Git'
```

Create a link for a regular user:

```bash
./scripts/create-invitation.sh user
```

Create an administrator or operator link:

```bash
./scripts/create-invitation.sh admin
./scripts/create-invitation.sh operator
```

provide an email address as the second script argument:

```bash
./scripts/create-invitation.sh user person@example.com
```

The script first creates the invitation, then calls Authentik's invitation
email endpoint. The recipient address is supplied at that moment; it does not
need to be stored in Git or in the Blueprint.

The email flow is:

```text
Script
  ↓
Create invitation through Authentik API
  ↓
Ask Authentik to send the invitation email
  ↓
SMTP server
  ↓
Recipient receives the enrollment link
```

