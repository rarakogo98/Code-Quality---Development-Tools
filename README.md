# 🔍 Code Quality & Development Tools Smart Contract

A comprehensive Clarity smart contract linter that provides automated code quality assurance and security checks for Stacks blockchain development.

## 🚀 Features

- **📋 Custom Linting Rules**: Create and manage custom code quality rules
- **🔒 Security Scanning**: Perform automated security vulnerability detection
- **📊 Quality Scoring**: Get detailed quality scores with grade classifications (A-F)
- **⚠️ Issue Classification**: Categorize issues by severity (critical, high, medium, low)
- **📈 User Statistics**: Track scanning history and performance metrics
- **🔧 Rule Management**: Enable/disable rules and update configurations

## 📦 Contract Structure

### Core Data Maps
- `linting-rules`: Stores custom linting rules with metadata
- `scan-results`: Records security scan results and quality scores
- `rule-violations`: Tracks specific rule violations with location details
- `user-stats`: Maintains user scanning statistics and performance data

## 🛠️ Usage Instructions

### Creating Linting Rules

```clarity
(contract-call? .code-quality-development-tools create-linting-rule 
    "unused-variable" 
    "Variables should be used after declaration"
    "medium"
    "best-practices")
```

### Performing Security Scans

```clarity
(contract-call? .code-quality-development-tools perform-security-scan
    'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM
    u5    ;; total issues
    u1    ;; critical issues  
    u2    ;; high issues
    u1    ;; medium issues
    u1)   ;; low issues
```

### Adding Rule Violations

```clarity
(contract-call? .code-quality-development-tools add-rule-violation
    u1    ;; scan-id
    u1    ;; rule-id
    u42   ;; line number
    u15   ;; column number
    "Unused variable 'temp-value' detected"
    "Remove unused variable or use it in computation")
```

### Toggling Rules

```clarity
(contract-call? .code-quality-development-tools toggle-rule u1)
```

## 📖 Read-Only Functions

### Get Rule Information
```clarity
(contract-call? .code-quality-development-tools get-rule u1)
```

### Get Scan Results
```clarity
(contract-call? .code-quality-development-tools get-scan-result u1)
```

### Get Quality Grade
```clarity
(contract-call? .code-quality-development-tools get-quality-grade u85)
;; Returns: "B"
```

### Get User Statistics
```clarity
(contract-call? .code-quality-development-tools get-user-stats 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

## 🎯 Quality Scoring System

The contract uses an intelligent scoring algorithm:

- **Base Score**: 100 points
- **Critical Issues**: -20 points each
- **High Issues**: -10 points each  
- **Other Issues**: -2 points each

### Grade Classifications
- **A Grade**: 90-100 points 🏆
- **B Grade**: 80-89 points ⭐
- **C Grade**: 70-79 points ✅
- **D Grade**: 60-69 points ⚠️
- **F Grade**: Below 60 points ❌

## 🔐 Security Features

- **Access Control**: Rule creators and contract owner can modify rules
- **Input Validation**: Comprehensive parameter validation
- **Error Handling**: Detailed error codes and messages

## 📊 Error Codes

- `u100`: Not authorized
- `u101`: Invalid rule parameters
- `u102`: Rule already exists
- `u103`: Rule not found
- `u104`: Invalid quality score
- `u105`: Scan not found

## 🚀 Getting Started

1. **Deploy Contract**: Deploy to Stacks testnet or mainnet
2. **Create Rules**: Define your custom linting rules
3. **Run Scans**: Perform security scans on target contracts
4. **Track Progress**: Monitor quality improvements over time

## 💻 Development

Built with Clarity smart contract language for the Stacks blockchain ecosystem.

### Prerequisites
- Clarinet CLI
- Node.js
- Stacks CLI

### Testing
```bash
clarinet test
```

### Deployment
```bash
clarinet deploy
```

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Commit changes
4. Push to branch
5. Create Pull Request

## 📄 License

Open source - feel free to contribute and improve! 🎉
