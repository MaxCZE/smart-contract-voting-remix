// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Voting is Ownable {

    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }

    struct Proposal {
        string description;
        uint voteCount;
    }

    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    event VoterRegistered(address voterAddress);
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted(address voter, uint proposalId);
    event SeeProposal(uint id, string description);

    mapping (address => Voter) private voters;
    address[] private voterAddresses;
    Proposal[] private proposals;
    Proposal[] private newProposals;

    uint private winningProposalId;
    WorkflowStatus private workflowStatus;

    function getWinningProposalId() public view verifyStatus(WorkflowStatus.VotesTallied) returns(uint) {
        return winningProposalId;
    }

    modifier verifyStatus(WorkflowStatus _workflowStatus) {
        require(workflowStatus == _workflowStatus, "It's not the good stage.");
        _;
    }

    constructor() Ownable(msg.sender) {
        workflowStatus = WorkflowStatus.RegisteringVoters;
    }

    function registerVoter(address _voterAddress) external onlyOwner verifyStatus(WorkflowStatus.RegisteringVoters) {
        require(voters[_voterAddress].isRegistered == false, "The voter is already registered!");
        voters[_voterAddress].isRegistered = true;
        voterAddresses.push(_voterAddress);
        emit VoterRegistered(_voterAddress);
    }

    function startProposalRegistrationSession() external onlyOwner verifyStatus(WorkflowStatus.RegisteringVoters) {
        workflowStatus = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, workflowStatus);
    }

    function stopProposalRegistrationSession() external onlyOwner verifyStatus(WorkflowStatus.ProposalsRegistrationStarted) {
        workflowStatus = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted, workflowStatus);
    }

    function submitProposal(string memory _proposal) external verifyStatus(WorkflowStatus.ProposalsRegistrationStarted) {
        require(voters[msg.sender].isRegistered, "The voter is not registered!");
        Proposal memory proposal;
        proposal.description = _proposal;
        proposal.voteCount = 0;
        proposals.push(proposal);
        emit ProposalRegistered(proposals.length-1);
    }

    function startVotingSession() external onlyOwner verifyStatus(WorkflowStatus.ProposalsRegistrationEnded) {
        workflowStatus = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded, workflowStatus);
    }

    function stopVotingSession() external onlyOwner verifyStatus(WorkflowStatus.VotingSessionStarted) {
        workflowStatus = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted, workflowStatus);
    }

    function getAllProposals() external view verifyStatus(WorkflowStatus.VotingSessionStarted) returns (string[] memory) {
        string[] memory allProposals = new string[](proposals.length);
        for (uint i = 0; i < proposals.length; i++) {
            allProposals[i] = proposals[i].description;
        }
        return allProposals;
    }

    function vote(uint _proposalId) external verifyStatus(WorkflowStatus.VotingSessionStarted) {
        require(voters[msg.sender].isRegistered, "The voter is not registered!");
        require(!voters[msg.sender].hasVoted, "The voter has already voted!");
        require(_proposalId < proposals.length, "The proposal doesn't exist!");

        proposals[_proposalId].voteCount += 1;

        voters[msg.sender].hasVoted = true;
        voters[msg.sender].votedProposalId = _proposalId;

        emit Voted(msg.sender, _proposalId);
    }

    function countVotes() external onlyOwner verifyStatus(WorkflowStatus.VotingSessionEnded) {
        
        uint maxVoteCount = 0;
        uint idxMaxVoteCount = 0;
        for (uint proposalIdx = 0; proposalIdx < proposals.length; proposalIdx++) {
            if (proposals[proposalIdx].voteCount > maxVoteCount) {
                maxVoteCount = proposals[proposalIdx].voteCount;
                idxMaxVoteCount = proposalIdx;
            }
        }

        delete newProposals;
        for (uint proposalIdx = 0; proposalIdx < proposals.length; proposalIdx++) {
            if (proposals[proposalIdx].voteCount == maxVoteCount) {
                newProposals.push(proposals[proposalIdx]);
            }
        }

        if(newProposals.length > 1) {
            delete proposals;
            proposals = newProposals;
            for (uint i = 0; i < voterAddresses.length; i++) {
                voters[voterAddresses[i]].hasVoted = false;
            }
            workflowStatus = WorkflowStatus.VotingSessionStarted;
            emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, workflowStatus);
        } else {
            winningProposalId = idxMaxVoteCount;
            workflowStatus = WorkflowStatus.VotesTallied;
            emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, workflowStatus);
        }
    }
}