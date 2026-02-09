# Contributing to Knative Airgap Deployment

Thank you for your interest in contributing! This document provides guidelines for contributing to this project.

## How to Contribute

### Reporting Issues

If you find a bug or have a suggestion:

1. **Check existing issues** to avoid duplicates
2. **Create a new issue** with:
   - Clear, descriptive title
   - Detailed description of the problem/suggestion
   - Steps to reproduce (for bugs)
   - Your environment details (OS, Kubernetes version, etc.)
   - Relevant logs or error messages
   - What you've already tried

### Suggesting Enhancements

We welcome suggestions for improvements:

1. **Open an issue** describing the enhancement
2. Explain **why** it would be useful
3. Provide **examples** of how it would work
4. Consider **alternatives** you've thought of

### Pull Requests

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Make your changes**
4. **Test thoroughly**
5. **Update documentation** if needed
6. **Commit your changes**: `git commit -m 'Add amazing feature'`
7. **Push to your fork**: `git push origin feature/amazing-feature`
8. **Open a Pull Request**

## Development Guidelines

### Code Style

**Shell Scripts**:
- Use `#!/bin/bash` shebang
- Enable strict mode: `set -e`
- Add descriptive comments
- Use meaningful variable names
- Include error checking
- Add usage examples in comments

**Markdown**:
- Use clear headings
- Include code blocks with syntax highlighting
- Add links to related documentation
- Keep lines reasonably short (80-120 chars)
- Use consistent formatting

### Testing

Before submitting:

1. **Test on fresh cluster**:
   ```bash
   ./scripts/cleanup.sh
   ./scripts/run-all.sh
   ```

2. **Verify documentation**:
   - Check for broken links
   - Ensure examples work
   - Update version numbers

3. **Test edge cases**:
   - What if registry fails?
   - What if images don't exist?
   - What if network is slow?

### Documentation

When adding features:

- Update README.md if user-facing
- Add to appropriate docs/ file
- Include examples
- Update FAQ if it answers common questions
- Update TROUBLESHOOTING if relevant

### Commit Messages

Write clear commit messages:

```
Short summary (50 chars or less)

More detailed explanation if needed. Wrap at 72 characters.
Explain what and why, not how.

- Bullet points are okay
- Use present tense: "Add feature" not "Added feature"
- Reference issues: "Fixes #123"
```

## Project Structure

```
knative-airgap/
├── scripts/          # All automation scripts
├── config/           # Configuration files (images.txt)
├── docs/             # Documentation
├── examples/         # Example manifests
├── README.md         # Main documentation
├── CONTRIBUTING.md   # This file
└── LICENSE           # MIT License
```

## Areas for Contribution

### High Priority

- [ ] Support for more Knative versions
- [ ] Better Kourier/Envoy configuration
- [ ] Istio integration guide
- [ ] Contour integration guide
- [ ] Harbor setup automation
- [ ] Image update automation

### Medium Priority

- [ ] Multi-architecture support
- [ ] Helm chart option
- [ ] Monitoring/observability guide
- [ ] Backup/restore scripts
- [ ] CI/CD integration examples

### Documentation

- [ ] Video tutorial
- [ ] More troubleshooting scenarios
- [ ] Production deployment checklist
- [ ] Security hardening guide
- [ ] Performance tuning guide

## Testing Checklist

Before submitting a PR:

- [ ] Scripts run without errors
- [ ] All components deploy successfully
- [ ] Documentation is updated
- [ ] Examples work correctly
- [ ] No hardcoded values (use variables)
- [ ] Error handling is adequate
- [ ] Code is commented appropriately
- [ ] CHANGELOG is updated (if applicable)

## Getting Help

- **Questions**: Open a GitHub issue with the `question` label
- **Discussion**: Use GitHub Discussions
- **Chat**: (Add Discord/Slack if available)

## Code of Conduct

### Our Standards

- Be respectful and inclusive
- Welcome newcomers
- Accept constructive criticism gracefully
- Focus on what's best for the community
- Show empathy towards others

### Unacceptable Behavior

- Harassment or discriminatory language
- Trolling or insulting/derogatory comments
- Public or private harassment
- Publishing others' private information
- Other conduct inappropriate for a professional setting

## Recognition

Contributors will be:
- Listed in CONTRIBUTORS.md (if we create one)
- Mentioned in release notes for significant contributions
- Given credit in commit messages

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Questions?

Don't hesitate to ask! Open an issue with the `question` label, and we'll be happy to help.

---

**Thank you for contributing!** 🎉
