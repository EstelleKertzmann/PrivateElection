# 🚀 Quick Start Guide

Get your Hello FHEVM Election dApp running in 5 minutes!

## Prerequisites

- Node.js (v16+) installed
- MetaMask browser extension
- Basic terminal/command line knowledge

## Step 1: Clone & Install

```bash
# Clone the repository
git clone https://github.com/your-username/hello-fhevm-election.git
cd hello-fhevm-election

# Install dependencies
npm install
```

## Step 2: Environment Setup

```bash
# Copy environment template
cp .env.example .env

# Edit .env file with your values:
# - Get Sepolia RPC URL from Infura/Alchemy
# - Export private key from MetaMask (Account Details > Export Private Key)
```

## Step 3: Deploy Contract

```bash
# Compile contracts
npm run compile

# Deploy to Sepolia testnet
npm run deploy
```

**Save the contract address from the output!**

## Step 4: Update Frontend

1. Open `public/index.html`
2. Find line with `CONTRACT_ADDRESS`
3. Replace with your deployed contract address

## Step 5: Run the App

```bash
# Start local server
npm run dev
```

The app opens at `http://localhost:3000`

## Step 6: Test Voting

1. **Connect MetaMask** (ensure you're on Sepolia testnet)
2. **Get test ETH** from [Sepolia Faucet](https://faucets.chain.link/sepolia)
3. **Wait for odd hour** (13:00, 15:00, 17:00, etc. UTC+3)
4. **Start election** if needed
5. **Select candidate** and vote
6. **Wait for even hour** (14:00, 16:00, 18:00, etc.)
7. **Reveal results**

## 🎉 Success!

You now have a working FHEVM dApp with:
- ✅ Encrypted votes
- ✅ Time-based phases
- ✅ Privacy-preserving results
- ✅ Beautiful UI

## Need Help?

- 📚 Read the full [Tutorial](./HELLO_FHEVM_TUTORIAL.md)
- 🐛 Check [Common Issues](./HELLO_FHEVM_TUTORIAL.md#common-issues--solutions)
- 💬 Open an [Issue](https://github.com/your-username/hello-fhevm-election/issues)

## What's Next?

- Add more candidates
- Customize the UI
- Deploy to production
- Build more FHEVM features!

Happy coding with FHEVM! 🔐✨