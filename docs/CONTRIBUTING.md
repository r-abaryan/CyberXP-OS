# Contributing to CyberXP-OS

## 🎉 Welcome!

Thank you for your interest in contributing to CyberXP-OS! We're building the world's first AI-powered defensive security operating system, and we need your help.

---

## 🌟 Ways to Contribute

### 1. Code Contributions
- Core OS improvements
- Build script enhancements
- Security tool integrations
- Dashboard/UI development
- Bug fixes

### 2. Documentation
- User guides and tutorials
- Configuration examples
- Deployment scenarios
- Troubleshooting guides
- Video tutorials

### 3. Testing
- Hardware compatibility testing
- Security testing and audits
- Performance benchmarking
- Bug reporting

### 4. Community
- Answer questions on Discord/GitHub
- Write blog posts and articles
- Create educational content
- Translate documentation

### 5. Security Research
- Vulnerability disclosure
- Threat detection improvements
- Custom detection rules
- Penetration testing

---

## 🚀 Getting Started

### 1. Set Up Development Environment

```bash
# Fork the repository on GitHub

# Clone your fork
git clone https://github.com/YOUR_USERNAME/CyberXP-OS
cd CyberXP-OS

# Add upstream remote
git remote add upstream https://github.com/abaryan/CyberXP-OS

# Clone CyberXP core (required)
cd ..
git clone https://github.com/abaryan/CyberXP
cd CyberXP-OS
```

### 2. Create Development Environment

```bash
# Set up development VM
./scripts/setup-dev-vm.sh

# Or build from scratch
sudo ./scripts/build-alpine-iso.sh
```

### 3. Create a Branch

```bash
# Update your fork
git fetch upstream
git checkout master
git merge upstream/master

# Create feature branch
git checkout -b feature/your-feature-name

# Or for bug fixes
git checkout -b fix/bug-description
```

---

## 📝 Development Workflow

### 1. Make Changes

```bash
# Edit files
nano scripts/build-alpine-iso.sh

# Test your changes
sudo ./scripts/build-alpine-iso.sh

# Verify ISO boots
./scripts/setup-dev-vm.sh
```

### 2. Code Standards

#### Shell Scripts
```bash
# Use shellcheck
shellcheck scripts/*.sh

# Format:
# - Use 4 spaces for indentation
# - Add comments for complex logic
# - Include error handling (set -e)
# - Use descriptive variable names
```

#### Python Code
```python
# Follow PEP 8
# Use type hints
# Add docstrings

def analyze_threat(alert: dict) -> dict:
    """
    Analyze security alert using AI.
    
    Args:
        alert: Alert data dictionary
        
    Returns:
        Analysis results with severity score
    """
    pass
```

#### Documentation
```markdown
# Use clear headings
# Include code examples
# Add troubleshooting sections
# Keep it beginner-friendly
```

### 3. Test Your Changes

```bash
# Run tests (when available)
./tests/run-all-tests.sh

# Manual testing checklist:
# [ ] ISO builds successfully
# [ ] System boots in VM
# [ ] CyberXP agent starts
# [ ] Dashboard accessible
# [ ] No new errors in logs
```

### 4. Commit Changes

```bash
# Stage changes
git add .

# Commit with descriptive message
git commit -m "feat: add automatic threat blocking

- Implemented auto-block for high-severity threats
- Added configuration option to enable/disable
- Updated documentation

Closes #123"
```

**Commit Message Format:**
```
<type>: <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code formatting (no logic changes)
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Maintenance tasks

### 5. Push and Create Pull Request

```bash
# Push to your fork
git push origin feature/your-feature-name

# Create pull request on GitHub
# Fill out the PR template
# Wait for review
```

---

## 🔍 Pull Request Process

### 1. PR Requirements

- [ ] Code follows project style guidelines
- [ ] All tests pass
- [ ] Documentation updated
- [ ] Commit messages follow convention
- [ ] PR description is clear and detailed
- [ ] No merge conflicts

### 2. PR Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Performance improvement
- [ ] Security enhancement

## Testing
How was this tested?

## Screenshots (if applicable)
Add screenshots here

## Checklist
- [ ] Code builds successfully
- [ ] Tests pass
- [ ] Documentation updated
- [ ] No breaking changes
```

### 3. Review Process

1. **Automated Checks**: CI/CD runs tests
2. **Code Review**: Maintainer reviews code
3. **Feedback**: Address any comments
4. **Approval**: PR approved by maintainer
5. **Merge**: PR merged to master

---

## 🐛 Bug Reports

### How to Report Bugs

1. **Search existing issues** first
2. **Use bug report template**
3. **Include detailed information**

### Bug Report Template

```markdown
**Describe the Bug**
Clear description of the bug

**To Reproduce**
Steps to reproduce:
1. Boot CyberXP-OS
2. Open dashboard
3. Click on '...'
4. See error

**Expected Behavior**
What should happen instead

**Screenshots**
Add screenshots if applicable

**Environment:**
- CyberXP-OS Version: [e.g. 0.1.0-alpha]
- Hardware: [VM, Physical, Cloud]
- Specs: [RAM, CPU, Disk]

**Logs**
```
Paste relevant logs here
```

**Additional Context**
Any other information
```

---

## 💡 Feature Requests

### How to Request Features

1. **Check existing feature requests**
2. **Use feature request template**
3. **Explain use case**

### Feature Request Template

```markdown
**Feature Description**
Clear description of the feature

**Problem Statement**
What problem does this solve?

**Proposed Solution**
How should it work?

**Alternatives Considered**
Other approaches you've considered

**Additional Context**
Mockups, examples, references
```

---

## 🏗️ Project Structure

```
CyberXP-OS/
├── build/              # Build artifacts (gitignored)
├── config/
│   ├── services/       # OpenRC init scripts
│   ├── desktop/        # Desktop configurations
│   └── system/         # System configs
├── docs/               # Documentation
├── scripts/            # Build and deployment scripts
│   ├── build-alpine-iso.sh
│   └── setup-dev-vm.sh
├── tests/              # Test scripts
└── tools/              # Helper utilities
```

---

## 🔒 Security Vulnerability Disclosure

### Reporting Security Issues

**DO NOT** open public GitHub issues for security vulnerabilities.

Instead:
1. Email: security@cyberxp-os.com
2. Include detailed description
3. Steps to reproduce
4. Potential impact
5. Suggested fix (if any)

### Security Response Process

1. **Acknowledgment**: Within 48 hours
2. **Assessment**: Within 1 week
3. **Fix Development**: ASAP (depending on severity)
4. **Disclosure**: Coordinated disclosure after fix

---

## 📋 Code Review Guidelines

### For Contributors

**Before Requesting Review:**
- [ ] Self-review your code
- [ ] Test thoroughly
- [ ] Update documentation
- [ ] Add comments for complex logic
- [ ] Ensure code is clean and readable

### For Reviewers

**Review Checklist:**
- [ ] Code quality and style
- [ ] Security implications
- [ ] Performance impact
- [ ] Documentation completeness
- [ ] Test coverage
- [ ] Backward compatibility

**Review Tone:**
- Be respectful and constructive
- Explain the "why" behind suggestions
- Recognize good work
- Focus on the code, not the person

---

## 🧪 Testing Guidelines

### Types of Tests

1. **Unit Tests**: Test individual functions
2. **Integration Tests**: Test component interactions
3. **System Tests**: Test entire system
4. **Security Tests**: Penetration testing, vulnerability scans

### Running Tests

```bash
# Run all tests
./tests/run-all-tests.sh

# Run specific test suite
./tests/test-build.sh
./tests/test-services.sh
./tests/test-security.sh
```

### Writing Tests

```bash
#!/bin/bash
# Test script template

set -e

echo "Testing: Feature X"

# Test case 1
if [[ condition ]]; then
    echo "✓ Test case 1 passed"
else
    echo "✗ Test case 1 failed"
    exit 1
fi

echo "All tests passed!"
```

---

## 📚 Documentation Guidelines

### Documentation Standards

- **Clear and concise**: Avoid jargon
- **Examples**: Include code examples
- **Screenshots**: Visual aids help
- **Up-to-date**: Update docs with code changes
- **Beginner-friendly**: Assume no prior knowledge

### Documentation Structure

```markdown
# Title

## Overview
Brief description

## Prerequisites
What's needed

## Steps
1. Step one
2. Step two

## Examples
Code examples

## Troubleshooting
Common issues

## Next Steps
What to do next
```

---

## 🌍 Community Guidelines

### Code of Conduct

- **Be respectful**: Treat everyone with respect
- **Be inclusive**: Welcome diverse perspectives
- **Be collaborative**: Work together constructively
- **Be patient**: Help newcomers learn
- **Be professional**: Keep discussions focused

### Communication Channels

- **GitHub Issues**: Bug reports, feature requests
- **GitHub Discussions**: Q&A, ideas, announcements
- **Discord**: Real-time chat, community support
- **Email**: security@cyberxp-os.com, support@cyberxp-os.com

---

## 🏆 Recognition

### Contributors

We recognize and appreciate all contributors!

- **README.md**: Contributors list
- **CHANGELOG.md**: Release notes mention contributors
- **Hall of Fame**: Top contributors highlighted

### Becoming a Maintainer

Active contributors may be invited to become maintainers:

**Requirements:**
- Consistent quality contributions
- Good understanding of project
- Helpful to community
- Available for code reviews

---

## 📖 Resources

### Learning Resources

- [Alpine Linux Documentation](https://docs.alpinelinux.org/)
- [OpenRC Guide](https://wiki.gentoo.org/wiki/OpenRC)
- [Suricata Documentation](https://suricata.readthedocs.io/)
- [CyberXP Documentation](https://github.com/abaryan/CyberXP)

### Development Tools

- **ShellCheck**: Shell script linter
- **markdownlint**: Markdown linter
- **QEMU**: Quick testing
- **VirtualBox**: VM testing

---

## ❓ FAQ

**Q: I'm new to open source. How do I start?**  
A: Start with documentation improvements or testing. Check "good first issue" labels on GitHub.

**Q: How long does code review take?**  
A: Usually within 1 week. Complex PRs may take longer.

**Q: Can I work on issues without assignment?**  
A: Yes! Comment on the issue first to avoid duplicate work.

**Q: Do I need to sign a CLA?**  
A: No, we use MIT license. Your contributions are automatically licensed under MIT.

---

## 📞 Contact

- **Project Lead**: [@abaryan](https://github.com/abaryan)
- **GitHub**: https://github.com/abaryan/CyberXP-OS

---

## 🙏 Thank You!

Every contribution, no matter how small, helps make CyberXP-OS better. Thank you for being part of this journey!

**Let's build the future of defensive security together!** 🛡️

---

**Last Updated:** October 2025  
**License:** MIT

