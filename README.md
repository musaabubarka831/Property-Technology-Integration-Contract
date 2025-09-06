# Property Technology Integration Contract

A comprehensive smart contract system for IoT device coordination, data analytics, and smart building system integration built with Clarity on the Stacks blockchain.

## 🏗️ Project Overview

This project implements two core smart contracts designed to revolutionize property technology management:

1. **IoT Device Coordination and Data Analytics** - Manages IoT device registration, sensor data collection, and provides real-time analytics
2. **Smart Building System Integration and Management** - Handles building unit management, system status monitoring, and maintenance scheduling

## 🎯 Features

### IoT Device Coordination Contract
- **Device Registration**: Secure device onboarding with principal-based authentication
- **Sensor Data Management**: Real-time data collection with timestamp tracking
- **Analytics Engine**: Aggregated data analytics (average, min, max calculations)
- **Access Control**: Owner-based authorization model
- **Data Integrity**: Immutable sensor data storage on blockchain

### Smart Building Management Contract
- **Unit Registration**: Complete building, floor, and unit metadata management
- **System Status Monitoring**: HVAC, lighting, and security system status tracking
- **Maintenance Scheduling**: Automated maintenance workflow management
- **Admin Authorization**: Multi-level access control for building operations
- **Real-time Updates**: Live system status updates and notifications

## 🛠️ Technical Architecture

### Built With
- **Clarity Language**: Smart contract development
- **Stacks Blockchain**: Decentralized deployment platform
- **Clarinet**: Development and testing framework

### Branch Strategy
- **main**: Production-ready code with comprehensive documentation
- **development**: Active development branch for new features and contracts

## 🚀 Quick Start

### Prerequisites
- [Clarinet](https://docs.hiro.so/clarinet) installed
- Node.js and npm (for testing)
- Git for version control

### Installation & Setup

```bash
# Clone the repository
git clone https://github.com/musaabubarka831/Property-Technology-Integration-Contract.git
cd Property-Technology-Integration-Contract

# Install dependencies
npm install

# Check contract syntax
clarinet check

# Run tests
clarinet test

# Start local development network
clarinet integrate
```

## 📋 Contract Details

### IoT Device Coordination (`iot-device-coordination.clar`)
- **Device Registration**: Maps principals to unique device identifiers
- **Data Collection**: Structured sensor data with block-height timestamps
- **Analytics Functions**: Real-time computation of sensor data statistics
- **Authorization**: Contract owner and device owner access controls

### Smart Building Management (`smart-building-management.clar`)
- **Building Registry**: Hierarchical building → floor → unit structure
- **System Management**: HVAC, lighting, and security system controls
- **Maintenance Tracking**: Scheduled and emergency maintenance workflows
- **Status Monitoring**: Real-time system health and operational status

## 🧪 Testing

```bash
# Run all tests
clarinet test

# Run specific contract tests
clarinet test --filter iot-device-coordination
clarinet test --filter smart-building-management

# Check contract syntax
clarinet check
```

## 📁 Project Structure

```
Property-Technology-Integration-Contract/
├── contracts/
│   ├── iot-device-coordination.clar
│   └── smart-building-management.clar
├── tests/
│   ├── iot-device-coordination_test.ts
│   └── smart-building-management_test.ts
├── settings/
│   ├── Devnet.toml
│   ├── Testnet.toml
│   └── Mainnet.toml
├── Clarinet.toml
├── package.json
└── README.md
```

## 🔐 Security Features

- **Principal-based Authentication**: All functions require valid principal verification
- **Owner Access Control**: Critical functions restricted to contract owners
- **Data Validation**: Input sanitization and type checking
- **Immutable Records**: Blockchain-based data integrity guarantee

## 🌐 Deployment

### Local Development
```bash
clarinet integrate
```

### Testnet Deployment
```bash
clarinet deploy --testnet
```

### Mainnet Deployment
```bash
clarinet deploy --mainnet
```

## 📖 Usage Examples

### Device Registration
```clarity
(contract-call? .iot-device-coordination register-device "sensor-001" "temperature-sensor")
```

### Submit Sensor Data
```clarity
(contract-call? .iot-device-coordination submit-sensor-data u123 u2500)
```

### Register Building Unit
```clarity
(contract-call? .smart-building-management register-unit "Building-A" u5 u101 "2-bedroom apartment")
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/new-feature`)
3. Commit changes (`git commit -m 'Add new feature'`)
4. Push to branch (`git push origin feature/new-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

For support, please open an issue in the GitHub repository or contact the development team.

## 🔄 Roadmap

- [ ] Integration with external IoT platforms
- [ ] Advanced analytics and machine learning features
- [ ] Mobile application interface
- [ ] Energy management optimization
- [ ] Predictive maintenance algorithms

---

**Built with ❤️ using Clarity and Stacks blockchain technology**
