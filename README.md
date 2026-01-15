# Finenzo 💰

**Finenzo** is a smart expense tracker built with Flutter that helps you manage your personal finances with ease. Track expenses, manage multiple wallets, analyze spending patterns, and export your financial data - all in one app.

## ✨ Features

- **📊 Expense & Income Tracking**: Easily log and categorize your transactions
- **👛 Multi-Wallet Support**: Manage multiple accounts (cash, bank, mobile money)
- **📈 Analytics & Reports**: Visualize your spending patterns with interactive charts
- **🔒 Biometric Security**: Secure your financial data with fingerprint/face authentication
- **📱 SMS Transaction Parsing**: Automatically detect transactions from SMS (Bangladesh mobile money services: bKash, NAGAD)
- **📤 Export Data**: Export your transactions to CSV, PDF, or Excel formats
- **🏷️ Custom Categories**: Create and manage custom expense and income categories
- **🎨 Modern UI**: Clean and intuitive Material Design interface
- **👤 Multi-Profile Support**: Manage finances for different profiles

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (3.8.1 or higher)
- Dart SDK
- Android Studio or VS Code with Flutter extensions
- For Android development: Android SDK

### Installation

1. Clone the repository:
```bash
git clone https://github.com/shafisma/Finenzo.git
cd Finenzo
```

2. Install dependencies:
```bash
flutter pub get
```

3. Generate required files (for Drift database):
```bash
flutter pub run build_runner build
```

4. Run the app:
```bash
flutter run
```

## 🛠️ Technology Stack

- **Framework**: Flutter 3.8.1
- **Language**: Dart
- **State Management**: Provider
- **Database**: Drift (SQLite)
- **Charts**: fl_chart
- **Security**: local_auth, flutter_secure_storage
- **SMS Parsing**: telephony package
- **Export**: csv, pdf, excel packages

## ⚠️ Known Issues

### Message Transaction Feature
The SMS transaction parsing feature is currently **not working as expected**. While the app can read SMS messages and attempt to parse transaction details from mobile money services, there are known issues with:
- Inconsistent SMS format parsing
- Limited pattern matching for various banks and services
- Reliability issues on different Android versions

We are aware of this limitation and are working to improve it. **Contributions are welcome!**

## 🤝 Contributing

We welcome contributions from the community! Whether you're fixing bugs, improving documentation, or adding new features, your help is appreciated.

### How to Contribute

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/AmazingFeature`
3. **Make your changes** and commit: `git commit -m 'Add some AmazingFeature'`
4. **Push to your branch**: `git push origin feature/AmazingFeature`
5. **Open a Pull Request**

### Areas Where We Need Help

- 🔧 **Fix the SMS Transaction Parsing**: Improve the regex patterns and reliability
- 🌍 **Internationalization**: Add support for more languages
- 🏦 **Bank Support**: Add SMS parsing patterns for more banks and financial services
- 📱 **iOS Support**: Extend features to work on iOS
- 🧪 **Testing**: Add unit and integration tests
- 📖 **Documentation**: Improve code documentation and user guides

### Development Guidelines

- Follow the existing code style and structure
- Test your changes thoroughly before submitting
- Update documentation if you're adding new features
- Keep pull requests focused on a single feature or fix

## 📄 License

This project is open source and available for use. Please check with the repository owner for specific license terms.

## 📧 Contact

For questions, suggestions, or issues, please open an issue on GitHub or contact the repository owner.

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- All contributors who help improve Finenzo
- Open source community for the excellent packages used in this project

---

**Made with ❤️ for better financial management**
