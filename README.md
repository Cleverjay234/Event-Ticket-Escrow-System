# 🎫 Event Ticket Escrow System

A decentralized smart contract system built on Stacks blockchain that holds ticket funds in escrow until event attendees verify that the event occurred. This ensures both organizers and attendees are protected in ticket transactions.

## 🚀 Features

- **🏛️ Escrow Protection**: Funds are held safely until event verification
- **🎪 Event Creation**: Organizers can create events with custom parameters
- **🎟️ Ticket Purchasing**: Secure ticket purchases with automatic escrow
- **✅ Community Verification**: Attendees verify events happened
- **💰 Automatic Payouts**: Funds released when verification threshold met
- **🔄 Refund System**: Automatic refunds for cancelled or unverified events
- **🎯 Reputation Tracking**: Track organizer performance and reliability
- **🎁 Ticket Transfers**: Transfer tickets to other users before events

## 📋 Contract Functions

### 🎭 Organizer Functions

#### `create-event`
Create a new event with escrow protection.
```clarity
(create-event "Concert Name" "Amazing live music event" u1000000 u100 u1000 u1200)
```
- `name`: Event name (max 100 chars)
- `description`: Event description (max 500 chars) 
- `ticket-price`: Price in microSTX (1 STX = 1,000,000 microSTX)
- `max-tickets`: Maximum tickets available
- `event-date`: Block height when event occurs
- `verification-deadline`: Block height deadline for verification

#### `claim-funds`
Claim escrowed funds after successful event verification.
```clarity
(claim-funds u1)
```

#### `cancel-event`
Cancel an event before it occurs (enables refunds).
```clarity
(cancel-event u1)
```

### 🎫 Attendee Functions

#### `purchase-ticket`
Buy a ticket with funds held in escrow.
```clarity
(purchase-ticket u1)
```

#### `verify-event`
Verify that an event occurred (must be ticket holder).
```clarity
(verify-event u1)
```

#### `request-refund`
Request refund for cancelled or unverified events.
```clarity
(request-refund u1)
```

#### `transfer-ticket`
Transfer your ticket to another user.
```clarity
(transfer-ticket u1 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

### 📊 Read-Only Functions

#### `get-event`
Get complete event information.
```clarity
(get-event u1)
```

#### `get-ticket`
Get ticket information for specific buyer.
```clarity
(get-ticket u1 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

#### `get-organizer-reputation`
Get organizer's reputation metrics.
```clarity
(get-organizer-reputation 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

## 🔧 How It Works

1. **📅 Event Creation**: Organizers create events with ticket price and verification deadlines
2. **🛒 Ticket Sales**: Users purchase tickets, funds go into escrow automatically  
3. **🎉 Event Happens**: Event occurs on specified date
4. **✅ Community Verification**: Ticket holders verify the event occurred
5. **💸 Fund Release**: When 50%+ of attendees verify, organizer can claim funds
6. **🔄 Refund Protection**: If verification fails, attendees get automatic refunds

## 💡 Verification System

The contract uses a **community verification** approach:
- Only ticket holders can verify events
- Organizers get funds when ≥50% of attendees verify
- If verification threshold isn't met by deadline, refunds are available
- Platform takes a small fee (2.5%) on successful events

## 🛡️ Security Features

- **⏰ Time-based Controls**: Events must be in future, verification has deadlines
- **🔒 Access Controls**: Only organizers can claim funds, only ticket holders verify
- **💰 Escrow Protection**: Funds locked until verification or refund conditions met
- **🚫 Fraud Prevention**: Can't double-purchase, transfer ownership tracking

## 📈 Platform Economics

- **Platform Fee**: 2.5% on successful events
- **Verification Threshold**: 50% of ticket holders must verify
- **Refund Window**: Available if event cancelled or verification fails

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet with STX for transactions

### Local Development
```bash
# Clone the repository
git clone <repository-url>
cd Event-Ticket-Escrow-System

# Check contract syntax (warnings about unchecked data are expected)
clarinet check

# Run tests
clarinet test

# Start local devnet
clarinet integrate
```

### Deployment
```bash
# Deploy to testnet
clarinet deploy --testnet

# Deploy to mainnet  
clarinet deploy --mainnet
```

## 📝 Example Usage

```clarity
;; Create an event
(contract-call? .Event-Ticket-Escrow create-event 
  "Rock Concert 2024" 
  "Amazing live rock concert with top bands"
  u5000000  ;; 5 STX per ticket
  u200      ;; 200 max tickets
  u1000     ;; Event at block 1000
  u1100)    ;; Verification deadline at block 1100

;; Purchase a ticket
(contract-call? .Event-Ticket-Escrow purchase-ticket u1)

;; After event, verify it happened
(contract-call? .Event-Ticket-Escrow verify-event u1)

;; Organizer claims funds
(contract-call? .Event-Ticket-Escrow claim-funds u1)
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## 📜 License

MIT License - see LICENSE file for details

## 🔗 Links

- [Stacks Documentation](https://docs.stacks.co/)
- [Clarity Language Reference](https://docs.stacks.co/clarity/)
- [Clarinet Documentation](https://github.com/hirosystems/clarinet)

---

Built with ❤️ on Stacks blockchain
