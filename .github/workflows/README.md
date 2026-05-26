# GitHub Actions Workflows

This directory contains automated workflows for building, releasing, and promoting the Portfolio Admin app.

## 🚀 Workflows

### 1. `release.yml` - Automated Release Building

**Trigger**: Automatically runs when you push a version tag (e.g., `v2.0.1`)

**What it does**:
1. ✅ Sets up Flutter and Java build environment
2. ✅ Runs tests (optional)
3. ✅ Builds release APK
4. ✅ Renames APK with version number
5. ✅ Creates GitHub Release with APK attached
6. ✅ Generates release notes from commits
7. ✅ Uploads APK as artifact (90-day retention)

**Usage**:
```bash
# 1. Update version in pubspec.yaml
# version: 2.1.0+3

# 2. Commit the change
git add pubspec.yaml
git commit -m "chore: bump version to 2.1.0"
git push

# 3. Create and push tag
git tag -a v2.1.0 -m "Release v2.1.0"
git push origin v2.1.0

# 4. Wait for workflow to complete (~5-10 minutes)
# 5. Check https://github.com/YOUR_USERNAME/YOUR_REPO/releases
```

**Features**:
- 🎯 Automatic APK building on tag push
- 📦 Renamed APK with version in filename
- 📝 Auto-generated release notes
- ⬆️ APK automatically uploaded to release
- 💾 Build artifacts stored for 90 days
- ✅ Caches dependencies for faster builds

---

### 2. `update-resume.yml` - Automated Resume Updates

**Trigger**: Runs when a new release is published, or manually

**What it does**:
1. ✅ Fetches latest release info from GitHub API
2. ✅ Generates `release-info.json` with app details
3. ✅ Updates README.md with latest release badge
4. ✅ Adds download section to README
5. ✅ Commits and pushes changes
6. ✅ (Optional) Triggers webhook to update external resume site

**Usage**:

**Automatic** (after release is published):
- Workflow runs automatically
- README is updated with new release info
- Changes are committed and pushed

**Manual trigger**:
```bash
# Via GitHub UI:
# 1. Go to Actions tab
# 2. Select "Update Resume with Latest Release"
# 3. Click "Run workflow"

# Via GitHub CLI:
gh workflow run update-resume.yml
```

**Generated Files**:
- `release-info.json` - Structured release data
- `README.md` - Updated with latest release info

---

## 📋 Setup Instructions

### Prerequisites
1. **Repository Permissions**:
   - Settings → Actions → General → Workflow permissions
   - Select "Read and write permissions"
   - Save

2. **Secrets** (Optional for resume webhook):
   - Settings → Secrets and variables → Actions
   - Add `RESUME_WEBHOOK_URL` if using external site updates

### First-Time Setup

1. **Create workflows directory**:
   ```bash
   mkdir -p .github/workflows
   ```

2. **Add workflow files**:
   - Copy `release.yml` and `update-resume.yml` to `.github/workflows/`

3. **Commit and push**:
   ```bash
   git add .github/workflows/
   git commit -m "ci: add automated release workflows"
   git push
   ```

4. **Test the workflow**:
   ```bash
   # Create a test tag
   git tag -a v2.0.2 -m "Test release"
   git push origin v2.0.2
   
   # Watch workflow run
   gh workflow view release.yml --web
   ```

---

## 🔄 Complete Release Process

### Automated Process (Recommended)

```bash
# 1. Make your changes and commit them
git add .
git commit -m "feat: add awesome new feature"
git push

# 2. Update version in pubspec.yaml
# Change: version: 2.1.0+3
git add pubspec.yaml
git commit -m "chore: bump version to 2.1.0"
git push

# 3. Create and push tag (triggers workflow)
git tag -a v2.1.0 -m "Release v2.1.0 - Awesome new feature"
git push origin v2.1.0

# 4. Wait for GitHub Actions to complete (~5-10 minutes)
# 5. Release is automatically created with APK!
```

### Manual Process (Fallback)

If workflows fail or you need manual control:

```bash
# 1. Build APK locally
flutter build apk --release

# 2. Create release with GitHub CLI
gh release create v2.1.0 \
  --title "v2.1.0 - Awesome Feature" \
  --notes "Release notes here" \
  build/app/outputs/flutter-apk/app-release.apk

# 3. Or use GitHub web UI
# Go to: https://github.com/YOUR_USERNAME/YOUR_REPO/releases/new
```

---

## 🎯 Workflow Status Badges

Add these to your README.md:

```markdown
![Build and Release](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/release.yml/badge.svg)
![Update Resume](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/update-resume.yml/badge.svg)
![Latest Release](https://img.shields.io/github/v/release/YOUR_USERNAME/YOUR_REPO?style=for-the-badge)
```

---

## 🛠️ Customization

### Change Build Configuration

Edit `release.yml`:

```yaml
# Change Flutter version
- name: Set up Flutter
  uses: subosito/flutter-action@v2
  with:
    flutter-version: '3.24.x'  # Change this

# Add build flavors
- name: Build APK
  run: flutter build apk --release --flavor production
```

### Add Custom Release Notes

Create a `RELEASE_TEMPLATE.md` in your repo:

```markdown
## What's New
- Feature 1
- Feature 2

## Bug Fixes
- Fix 1

## Known Issues
- None
```

Then reference it in the workflow:
```yaml
- name: Create GitHub Release
  uses: softprops/action-gh-release@v1
  with:
    body_path: RELEASE_TEMPLATE.md
```

### Trigger Resume Webhook

Enable the webhook section in `update-resume.yml`:

```yaml
- name: Trigger Resume Site Update
  if: true  # Change from false to true
  run: |
    curl -X POST ${{ secrets.RESUME_WEBHOOK_URL }} \
      -H "Content-Type: application/json" \
      -d @release-info.json
```

Add webhook URL to secrets:
```bash
gh secret set RESUME_WEBHOOK_URL --body "https://your-resume-site.com/api/update"
```

---

## 📊 Monitoring Workflows

### View Workflow Runs
```bash
# List all runs
gh run list --workflow=release.yml

# View specific run
gh run view <run-id>

# Watch live run
gh run watch
```

### Debug Failed Workflows
```bash
# View logs
gh run view <run-id> --log

# Re-run failed jobs
gh run rerun <run-id>
```

---

## 🚨 Troubleshooting

### Build Fails

**Problem**: Gradle build errors
```
Solution: Clear cache and retry
- Delete .gradle folders locally
- Re-run workflow
```

**Problem**: Out of memory
```
Solution: Increase Gradle memory in android/gradle.properties:
org.gradle.jvmargs=-Xmx4096m
```

### Release Creation Fails

**Problem**: Permission denied
```
Solution: Check workflow permissions
Settings → Actions → General → Workflow permissions
Enable "Read and write permissions"
```

**Problem**: Tag already exists
```
Solution: Delete and recreate tag
git tag -d v2.0.1
git push origin :refs/tags/v2.0.1
git tag -a v2.0.1 -m "Release v2.0.1"
git push origin v2.0.1
```

---

## 📝 Best Practices

1. **Version Numbering**: Use semantic versioning (MAJOR.MINOR.PATCH)
   - `v2.0.0` - Major release (breaking changes)
   - `v2.1.0` - Minor release (new features)
   - `v2.1.1` - Patch release (bug fixes)

2. **Tag Messages**: Write descriptive tag messages
   ```bash
   git tag -a v2.1.0 -m "Release v2.1.0 - Native DOOM engine and settings"
   ```

3. **Test Before Tagging**: Always test locally before pushing tags
   ```bash
   flutter build apk --release
   # Test the APK on device
   # Then create tag
   ```

4. **Release Notes**: Keep `RELEASE_NOTES_v*.md` files for major releases

5. **Clean Tags**: Don't push incomplete or test tags to production

---

## 🎉 Success Checklist

After workflow completes:

- [ ] Check GitHub Actions tab - all green ✅
- [ ] View release page - APK is attached
- [ ] Download and test APK on device
- [ ] README.md is updated (if using update-resume workflow)
- [ ] Release notes are accurate
- [ ] Download link works

---

## 📚 Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Flutter Build Documentation](https://docs.flutter.dev/deployment/android)
- [Semantic Versioning](https://semver.org/)
- [GitHub Releases Guide](https://docs.github.com/en/repositories/releasing-projects-on-github)

---

**Workflows Version**: 1.0.0  
**Last Updated**: May 2026  
**Maintainer**: Emmanuel Korir
