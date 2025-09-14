// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { FHE, euint8, ebool } from "@fhevm/solidity/lib/FHE.sol";
import { SepoliaConfig } from "@fhevm/solidity/config/ZamaConfig.sol";

contract PrivateElection is SepoliaConfig {
    
    address public owner;
    uint8 public currentElectionRound;
    uint256 public lastElectionTime;
    
    // UTC+3 timezone offset (3 hours = 10800 seconds)
    uint256 constant UTC_OFFSET = 10800;
    
    struct Candidate {
        string name;
        bool isActive;
        uint256 addedAt;
    }
    
    struct EncryptedVote {
        euint8 candidateId;
        bool hasVoted;
        uint256 timestamp;
    }
    
    struct ElectionRound {
        bool isActive;
        bool votingEnded;
        bool resultsRevealed;
        uint256 startTime;
        uint256 endTime;
        uint256 totalVoters;
        address[] voters;
        mapping(uint8 => uint256) publicResults; // Decrypted results
        uint8 winnerCandidateId;
        uint256 winnerVoteCount;
    }
    
    mapping(uint8 => Candidate) public candidates;
    mapping(uint8 => ElectionRound) public electionRounds;
    mapping(uint8 => mapping(address => EncryptedVote)) public voterRecords;
    
    uint8 public totalCandidates;
    uint8 public maxCandidates = 10;
    
    event ElectionStarted(uint8 indexed round, uint256 startTime);
    event VoteCast(address indexed voter, uint8 indexed round);
    event ElectionEnded(uint8 indexed round, uint8 winnerId, uint256 winnerVotes);
    event CandidateAdded(uint8 indexed candidateId, string name);
    event CandidateRemoved(uint8 indexed candidateId);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }
    
    modifier onlyDuringVotingTime() {
        require(isVotingTimeActive(), "Voting is not active");
        _;
    }
    
    modifier onlyDuringRevealTime() {
        require(isRevealTimeActive(), "Results reveal time is not active");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        currentElectionRound = 1;
        lastElectionTime = block.timestamp;
        totalCandidates = 0;
        
        // Add default candidates
        _addCandidate("Alice Johnson");
        _addCandidate("Bob Smith");
        _addCandidate("Carol Davis");
        _addCandidate("David Wilson");
    }
    
    // Add a new candidate (only owner)
    function addCandidate(string calldata name) external onlyOwner {
        _addCandidate(name);
    }
    
    function _addCandidate(string memory name) private {
        require(totalCandidates < maxCandidates, "Max candidates reached");
        require(bytes(name).length > 0, "Name cannot be empty");
        
        totalCandidates++;
        candidates[totalCandidates] = Candidate({
            name: name,
            isActive: true,
            addedAt: block.timestamp
        });
        
        emit CandidateAdded(totalCandidates, name);
    }
    
    // Remove a candidate (only owner)
    function removeCandidate(uint8 candidateId) external onlyOwner {
        require(candidateId > 0 && candidateId <= totalCandidates, "Invalid candidate ID");
        require(candidates[candidateId].isActive, "Candidate already inactive");
        
        candidates[candidateId].isActive = false;
        emit CandidateRemoved(candidateId);
    }
    
    // Check if it's odd hour (voting time: 13:00, 15:00, 17:00...)
    function isOddHour() public view returns (bool) {
        uint256 adjustedTime = block.timestamp + UTC_OFFSET;
        uint256 currentHour = (adjustedTime / 3600) % 24;
        return currentHour % 2 == 1;
    }
    
    // Check if it's even hour (reveal time: 14:00, 16:00, 18:00...)
    function isEvenHour() public view returns (bool) {
        uint256 adjustedTime = block.timestamp + UTC_OFFSET;
        uint256 currentHour = (adjustedTime / 3600) % 24;
        return currentHour % 2 == 0;
    }
    
    // Check if voting is active
    function isVotingTimeActive() public view returns (bool) {
        if (!electionRounds[currentElectionRound].isActive) return false;
        if (electionRounds[currentElectionRound].votingEnded) return false;
        return isOddHour() || (!isEvenHour() && electionRounds[currentElectionRound].isActive);
    }
    
    // Check if results reveal time is active
    function isRevealTimeActive() public view returns (bool) {
        return isEvenHour() && 
               electionRounds[currentElectionRound].isActive && 
               !electionRounds[currentElectionRound].resultsRevealed;
    }
    
    // Start a new election round (during odd hours)
    function startElectionRound() external {
        require(isOddHour(), "Elections can only start during odd hours");
        require(!electionRounds[currentElectionRound].isActive || 
                electionRounds[currentElectionRound].resultsRevealed, 
                "Current election is still active");
        require(totalCandidates >= 2, "Need at least 2 candidates");
        
        ElectionRound storage newRound = electionRounds[currentElectionRound];
        newRound.isActive = true;
        newRound.votingEnded = false;
        newRound.resultsRevealed = false;
        newRound.startTime = block.timestamp;
        newRound.totalVoters = 0;
        newRound.winnerCandidateId = 0;
        newRound.winnerVoteCount = 0;
        
        emit ElectionStarted(currentElectionRound, block.timestamp);
    }
    
    // Cast encrypted vote
    function castVote(uint8 candidateId) external onlyDuringVotingTime {
        require(candidateId > 0 && candidateId <= totalCandidates, "Invalid candidate ID");
        require(candidates[candidateId].isActive, "Candidate is not active");
        require(!voterRecords[currentElectionRound][msg.sender].hasVoted, 
                "Already voted in this round");
        
        // Encrypt the vote
        euint8 encryptedVote = FHE.asEuint8(candidateId);
        
        voterRecords[currentElectionRound][msg.sender] = EncryptedVote({
            candidateId: encryptedVote,
            hasVoted: true,
            timestamp: block.timestamp
        });
        
        electionRounds[currentElectionRound].voters.push(msg.sender);
        electionRounds[currentElectionRound].totalVoters++;
        
        // Set ACL permissions
        FHE.allowThis(encryptedVote);
        FHE.allow(encryptedVote, msg.sender);
        
        emit VoteCast(msg.sender, currentElectionRound);
    }
    
    // Reveal election results (during even hours)
    function revealResults() external onlyDuringRevealTime {
        require(electionRounds[currentElectionRound].isActive, "No active election");
        require(!electionRounds[currentElectionRound].resultsRevealed, "Results already revealed");
        require(electionRounds[currentElectionRound].totalVoters > 0, "No votes cast");
        
        ElectionRound storage round = electionRounds[currentElectionRound];
        round.votingEnded = true;
        round.endTime = block.timestamp;
        
        // In a real implementation, this would use FHE decryption requests
        // For this demo, we'll simulate the result counting process
        _countVotes();
        
        round.resultsRevealed = true;
        
        emit ElectionEnded(currentElectionRound, round.winnerCandidateId, round.winnerVoteCount);
        
        // Move to next round
        currentElectionRound++;
    }
    
    // Simulate vote counting (in real FHE implementation, this would be done via decryption)
    function _countVotes() private {
        ElectionRound storage round = electionRounds[currentElectionRound];
        
        // Initialize vote counts
        for (uint8 i = 1; i <= totalCandidates; i++) {
            round.publicResults[i] = 0;
        }
        
        // For demonstration, we'll use a simplified counting method
        // In real FHE, encrypted votes would be homomorphically tallied and then decrypted
        uint256 voterCount = round.voters.length;
        if (voterCount > 0) {
            // Simulate vote distribution (this is just for demo purposes)
            uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % 100;
            
            for (uint8 i = 1; i <= totalCandidates; i++) {
                if (candidates[i].isActive) {
                    round.publicResults[i] = (seed * i + voterCount) % (voterCount + 1);
                }
            }
            
            // Find winner
            uint256 maxVotes = 0;
            uint8 winner = 1;
            for (uint8 i = 1; i <= totalCandidates; i++) {
                if (candidates[i].isActive && round.publicResults[i] > maxVotes) {
                    maxVotes = round.publicResults[i];
                    winner = i;
                }
            }
            
            round.winnerCandidateId = winner;
            round.winnerVoteCount = maxVotes;
        }
    }
    
    // Get current election round info
    function getCurrentElectionInfo() external view returns (
        uint8 round,
        bool isActive,
        bool votingEnded,
        bool resultsRevealed,
        uint256 startTime,
        uint256 totalVoters,
        uint8 winnerCandidateId,
        uint256 winnerVoteCount
    ) {
        ElectionRound storage currentRound = electionRounds[currentElectionRound];
        return (
            currentElectionRound,
            currentRound.isActive,
            currentRound.votingEnded,
            currentRound.resultsRevealed,
            currentRound.startTime,
            currentRound.totalVoters,
            currentRound.winnerCandidateId,
            currentRound.winnerVoteCount
        );
    }
    
    // Check if voter has voted in current round
    function hasVoted(address voter) external view returns (bool) {
        return voterRecords[currentElectionRound][voter].hasVoted;
    }
    
    // Get candidate info
    function getCandidate(uint8 candidateId) external view returns (
        string memory name,
        bool isActive,
        uint256 addedAt
    ) {
        require(candidateId > 0 && candidateId <= totalCandidates, "Invalid candidate ID");
        Candidate storage candidate = candidates[candidateId];
        return (candidate.name, candidate.isActive, candidate.addedAt);
    }
    
    // Get all active candidates
    function getActiveCandidates() external view returns (
        uint8[] memory candidateIds,
        string[] memory names
    ) {
        uint8 activeCount = 0;
        for (uint8 i = 1; i <= totalCandidates; i++) {
            if (candidates[i].isActive) {
                activeCount++;
            }
        }
        
        candidateIds = new uint8[](activeCount);
        names = new string[](activeCount);
        
        uint8 index = 0;
        for (uint8 i = 1; i <= totalCandidates; i++) {
            if (candidates[i].isActive) {
                candidateIds[index] = i;
                names[index] = candidates[i].name;
                index++;
            }
        }
        
        return (candidateIds, names);
    }
    
    // Get election results for a specific round
    function getElectionResults(uint8 roundNumber) external view returns (
        bool resultsRevealed,
        uint8 winnerCandidateId,
        string memory winnerName,
        uint256 winnerVoteCount,
        uint256 totalVoters
    ) {
        require(roundNumber > 0 && roundNumber <= currentElectionRound, "Invalid round number");
        
        ElectionRound storage round = electionRounds[roundNumber];
        string memory winnerNameStr = "";
        
        if (round.resultsRevealed && round.winnerCandidateId > 0) {
            winnerNameStr = candidates[round.winnerCandidateId].name;
        }
        
        return (
            round.resultsRevealed,
            round.winnerCandidateId,
            winnerNameStr,
            round.winnerVoteCount,
            round.totalVoters
        );
    }
    
    // Get candidate vote count for a specific round (only after results are revealed)
    function getCandidateVotes(uint8 roundNumber, uint8 candidateId) external view returns (uint256) {
        require(roundNumber > 0 && roundNumber <= currentElectionRound, "Invalid round number");
        require(candidateId > 0 && candidateId <= totalCandidates, "Invalid candidate ID");
        require(electionRounds[roundNumber].resultsRevealed, "Results not revealed yet");
        
        return electionRounds[roundNumber].publicResults[candidateId];
    }
    
    // Get current UTC+3 hour
    function getCurrentHourUTC3() external view returns (uint256) {
        uint256 adjustedTime = block.timestamp + UTC_OFFSET;
        return (adjustedTime / 3600) % 24;
    }
}