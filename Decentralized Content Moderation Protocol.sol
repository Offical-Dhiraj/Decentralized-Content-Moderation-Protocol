
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Decentralized Content Moderation Protocol
 * @dev A smart contract for community-driven content moderation
 * @author Decentralized Content Moderation Team
 */
contract Project {
    // Struct to represent content
    struct Content {
        uint256 id;
        address author;
        string contentHash; // IPFS hash or content identifier
        uint256 timestamp;
        bool isActive;
        uint256 reportCount;
        ContentStatus status;
    }
    
    // Struct to represent a moderation report
    struct Report {
        uint256 contentId;
        address reporter;
        string reason;
        uint256 timestamp;
        bool isProcessed;
    }
    
    // Enum for content status
    enum ContentStatus {
        Active,
        UnderReview,
        Flagged,
        Removed
    }
    
    // State variables
    mapping(uint256 => Content) public contents;
    mapping(uint256 => Report) public reports;
    mapping(address => bool) public moderators;
    mapping(uint256 => mapping(address => bool)) public hasReported;
    
    uint256 public contentCounter;
    uint256 public reportCounter;
    uint256 public constant REPORT_THRESHOLD = 3; // Content goes under review after 3 reports
    
    address public owner;
    
    // Events
    event ContentSubmitted(uint256 indexed contentId, address indexed author, string contentHash);
    event ContentReported(uint256 indexed contentId, address indexed reporter, string reason);
    event ContentModerated(uint256 indexed contentId, ContentStatus newStatus, address indexed moderator);
    event ModeratorAdded(address indexed moderator);
    event ModeratorRemoved(address indexed moderator);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyModerator() {
        require(moderators[msg.sender] || msg.sender == owner, "Only moderators can call this function");
        _;
    }
    
    modifier contentExists(uint256 _contentId) {
        require(_contentId > 0 && _contentId <= contentCounter, "Content does not exist");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        moderators[msg.sender] = true; // Owner is default moderator
    }
    
    /**
     * @dev Core Function 1: Submit content to the platform
     * @param _contentHash IPFS hash or identifier of the content
     */
    function submitContent(string memory _contentHash) external {
        require(bytes(_contentHash).length > 0, "Content hash cannot be empty");
        
        contentCounter++;
        
        contents[contentCounter] = Content({
            id: contentCounter,
            author: msg.sender,
            contentHash: _contentHash,
            timestamp: block.timestamp,
            isActive: true,
            reportCount: 0,
            status: ContentStatus.Active
        });
        
        emit ContentSubmitted(contentCounter, msg.sender, _contentHash);
    }
    
    /**
     * @dev Core Function 2: Report content for moderation
     * @param _contentId ID of the content to report
     * @param _reason Reason for reporting the content
     */
    function reportContent(uint256 _contentId, string memory _reason) external contentExists(_contentId) {
        require(contents[_contentId].isActive, "Content is not active");
        require(!hasReported[_contentId][msg.sender], "You have already reported this content");
        require(contents[_contentId].author != msg.sender, "Cannot report your own content");
        require(bytes(_reason).length > 0, "Report reason cannot be empty");
        
        reportCounter++;
        
        reports[reportCounter] = Report({
            contentId: _contentId,
            reporter: msg.sender,
            reason: _reason,
            timestamp: block.timestamp,
            isProcessed: false
        });
        
        hasReported[_contentId][msg.sender] = true;
        contents[_contentId].reportCount++;
        
        // Automatically flag content if it reaches the threshold
        if (contents[_contentId].reportCount >= REPORT_THRESHOLD && 
            contents[_contentId].status == ContentStatus.Active) {
            contents[_contentId].status = ContentStatus.UnderReview;
        }
        
        emit ContentReported(_contentId, msg.sender, _reason);
    }
    
    /**
     * @dev Core Function 3: Moderate content (moderator only)
     * @param _contentId ID of the content to moderate
     * @param _newStatus New status for the content
     */
    function moderateContent(uint256 _contentId, ContentStatus _newStatus) external onlyModerator contentExists(_contentId) {
        require(contents[_contentId].isActive, "Content is not active");
        
        Content storage content = contents[_contentId];
        content.status = _newStatus;
        
        // If content is removed, deactivate it
        if (_newStatus == ContentStatus.Removed) {
            content.isActive = false;
        }
        
        emit ContentModerated(_contentId, _newStatus, msg.sender);
    }
    
    // Additional utility functions
    
    /**
     * @dev Add a new moderator (owner only)
     * @param _moderator Address to be added as moderator
     */
    function addModerator(address _moderator) external onlyOwner {
        require(_moderator != address(0), "Invalid moderator address");
        require(!moderators[_moderator], "Address is already a moderator");
        
        moderators[_moderator] = true;
        emit ModeratorAdded(_moderator);
    }
    
    /**
     * @dev Remove a moderator (owner only)
     * @param _moderator Address to be removed from moderators
     */
    function removeModerator(address _moderator) external onlyOwner {
        require(_moderator != owner, "Cannot remove owner as moderator");
        require(moderators[_moderator], "Address is not a moderator");
        
        moderators[_moderator] = false;
        emit ModeratorRemoved(_moderator);
    }
    
    /**
     * @dev Get content details
     * @param _contentId ID of the content
     * @return Content struct
     */
    function getContent(uint256 _contentId) external view contentExists(_contentId) returns (Content memory) {
        return contents[_contentId];
    }
    
    /**
     * @dev Get report details
     * @param _reportId ID of the report
     * @return Report struct
     */
    function getReport(uint256 _reportId) external view returns (Report memory) {
        require(_reportId > 0 && _reportId <= reportCounter, "Report does not exist");
        return reports[_reportId];
    }
    
    /**
     * @dev Check if content is flagged or under review
     * @param _contentId ID of the content
     * @return boolean indicating if content needs moderation
     */
    function needsModeration(uint256 _contentId) external view contentExists(_contentId) returns (bool) {
        ContentStatus status = contents[_contentId].status;
        return status == ContentStatus.UnderReview || status == ContentStatus.Flagged;
    }
}
