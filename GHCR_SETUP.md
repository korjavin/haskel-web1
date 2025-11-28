# GitHub Container Registry (GHCR) Setup Guide

This guide explains how the Docker images are automatically built and published to GitHub Container Registry.

## How It Works

### Automatic Builds

The GitHub Actions workflow (`.github/workflows/docker-build.yml`) automatically builds and pushes Docker images when:

1. **Push to branches:**
   - `main` or `master` branch → creates `latest` tag
   - Any `claude/**` branch → creates branch-specific tag
   - Creates SHA-tagged images for each commit

2. **Git tags:**
   - Push a tag like `v1.0.0` → creates `v1.0.0`, `v1.0`, and `v1` tags

3. **Pull requests:**
   - Builds the image but doesn't push (for testing)

4. **Manual trigger:**
   - Can be triggered manually from GitHub Actions UI

### Image Tags

After a successful build, images are available at:

```
ghcr.io/korjavin/haskel-web1:latest              # Latest from main/master
ghcr.io/korjavin/haskel-web1:main                # Main branch
ghcr.io/korjavin/haskel-web1:claude-branch-name  # Specific branch
ghcr.io/korjavin/haskel-web1:main-sha-abc123     # Specific commit
ghcr.io/korjavin/haskel-web1:v1.0.0              # Semantic version
ghcr.io/korjavin/haskel-web1:v1.0                # Major.minor version
ghcr.io/korjavin/haskel-web1:v1                  # Major version
```

## First Time Setup

### 1. Enable GitHub Packages

The repository is already configured with the workflow. No additional setup is needed as the workflow uses `GITHUB_TOKEN` which is automatically available.

### 2. Make Images Public (Optional)

By default, GHCR images are private. To make them public:

1. Go to your GitHub profile → Packages
2. Find the `haskel-web1` package
3. Click on it
4. Go to "Package settings"
5. Scroll down to "Danger Zone"
6. Click "Change visibility" → "Public"

This allows anyone to pull the images without authentication.

### 3. Trigger First Build

Push to the repository or manually trigger the workflow:

1. Go to repository → Actions
2. Select "Build and Push Docker Image" workflow
3. Click "Run workflow"
4. Select the branch
5. Click "Run workflow"

## Using Images in Portainer

### Public Images

If the image is public, simply use it in your `docker-compose.yml`:

```yaml
services:
  tictactoe:
    image: ghcr.io/korjavin/haskel-web1:latest
    # ... rest of config
```

### Private Images

If the image is private, you need to authenticate:

1. **Create a Personal Access Token (PAT):**
   - Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
   - Click "Generate new token (classic)"
   - Give it a name like "Portainer GHCR"
   - Select scopes: `read:packages`
   - Click "Generate token"
   - Copy the token (you won't see it again!)

2. **Add registry in Portainer:**
   - Go to Portainer → Registries
   - Click "Add registry"
   - Select "Custom registry"
   - Name: `GitHub Container Registry`
   - Registry URL: `ghcr.io`
   - Username: Your GitHub username
   - Password: The PAT you just created
   - Click "Add registry"

3. **Use in stack:**
   - When deploying the stack, Portainer will automatically authenticate

## Versioning Strategy

### During Development

Push to branches creates branch-specific tags:
```bash
git push origin feature/my-feature
# Creates: ghcr.io/korjavin/haskel-web1:feature-my-feature
```

### Creating Releases

Use semantic versioning:

```bash
# Create and push a tag
git tag v1.0.0
git push origin v1.0.0

# This creates multiple tags:
# - ghcr.io/korjavin/haskel-web1:v1.0.0
# - ghcr.io/korjavin/haskel-web1:v1.0
# - ghcr.io/korjavin/haskel-web1:v1
```

### In Production

Always use specific versions in production:

```yaml
# ❌ Not recommended for production
image: ghcr.io/korjavin/haskel-web1:latest

# ✅ Recommended for production
image: ghcr.io/korjavin/haskel-web1:v1.0.0
```

## Viewing Build Logs

1. Go to repository → Actions
2. Click on the workflow run
3. Click on the "build-and-push" job
4. Expand the steps to see logs

## Troubleshooting

### Build Failed

Check the Actions logs for errors. Common issues:
- Syntax errors in Haskell code
- Missing dependencies in package.yaml
- Dockerfile syntax errors

### Cannot Pull Image

1. Check if image exists: Go to GitHub → Packages
2. If private, ensure you're authenticated
3. Check image tag is correct

### Portainer Cannot Pull

1. Verify registry is configured correctly
2. Check PAT has `read:packages` permission
3. Ensure PAT hasn't expired
4. Test manually: `docker login ghcr.io -u USERNAME -p TOKEN`

## Manual Build and Push

If you want to build and push manually:

```bash
# Login to GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Build
docker build -t ghcr.io/korjavin/haskel-web1:my-tag .

# Push
docker push ghcr.io/korjavin/haskel-web1:my-tag
```

## Best Practices

1. **Use specific versions in production** - Don't rely on `latest`
2. **Tag releases** - Use semantic versioning for releases
3. **Make images public** - If it's open source, make packages public
4. **Monitor build times** - GitHub Actions has usage limits
5. **Clean up old images** - Regularly delete unused tags to save space

## Resources

- [GitHub Container Registry Documentation](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [Docker Build Push Action](https://github.com/docker/build-push-action)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
