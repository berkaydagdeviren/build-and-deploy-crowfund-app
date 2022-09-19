// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "./IERC20.sol";

contract CrowdFund {

    //events 
    
    event Launch(
        uint id, 
        address indexed creator,
        uint goal,
        uint32 startAt,
        uint32 endAt
        );
    
    event Cancel(uint id);

    event Pledge(
        uint indexed id, 
        address indexed caller, 
        uint amount
        );

    event Unpledge(
        uint indexed id, 
        address indexed caller, 
        uint amount
        );
    
    event Claim(_id);
    event Refund(uint indexed id, address indexed caller, uint amount);
    struct Campaign {
        address creator;
        uint goal;
        uint pledged;
        uint32 startAt;
        uint32 endAt;
        bool claimed;
    }

    IERC20 immutable public token;

    uint public count; // unique id for token

    mapping(uint => Campaign) public campaigns; // campaigns map
    mapping (uint => mapping(address => uint)) public plegedAmount; // users' pledged coins amount

    // construct with IERC20 token
    constructor(address _token){
        token = IERC20(_token);
    }
    
    // launc function

    function launch(uint _goal, uint32 _startAt, uint32 _endAt) external {
    
        //if function is started and not ended 
        
        require(_startAt >= block.timestamp, "Event has not started yet.");
        require(_endAt >= _startAt, "Event has ended.");
        require(_endAt >= block.timestamp + 90 days, "Event cannot be longer than 90 days");

        count += 1;
        
        //launch with Campaign struct
        
        campaigns[count] = Campaign({
            creator: msg.sender,
            goal: _goal,
            pledged: 0,
            startAt: _startAt,
            endAt: _endAt,
            claimed: false
        });

        emit Launch(count, msg.sender, _goal, _startAt, _endAt);
    }
    
    // cancel function
    
    function cancel(uint _id) external {
        Campaign memory campaign = campaigns[_id];
        
        // make sure sender is the creator and campaign has not started
        
        require(msg.sender == campaign.creator, "Only creator can cancel the event");
        require(block.timestamp < campaign.startAt, "Campaign already started");
        delete campaigns[_id];
        emit Cancel(_id);
    }
    
    //pledge function
    
    function pledge(uint _id, uint _amount) external {
         Campaign storage campaign = campaigns[_id];
         
         // if campaign started and not ended
         
         require(block.timestamp >= campaign.startAt, "NOT started");
         require(block.timestamp <= campaign.endAt, "ended");
         
         //increment pledged
         
         campaign.pledged += _amount;
         plegedAmount[_id][msg.sender] += _amount;
         
         //transfer token to the creator of fund
         token.transferFrom(msg.sender, address(this), _amount);

         emit Pledge(_id, msg.sender, _amount);
    }
    
    // unpledge function
    
    function unpledge(uint _id, uint _amount) external {
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp <= campaign.endAt, "ended");
        campaign.pledged -= _amount;
        token.transfer(msg.sender, _amount);

        emit Unpledge(_id, msg.sender, _amount);
    }
    
    // claim pledge function

    function claim(uint _id) external {
        Campaign storage campaign = campaigns[_id];
        
        // make sure msg sender is the creator and campaign has ended && goal achieved
        require(msg.sender == campaign.creator, "not creator");
        require(block.timestamp >= campaign.endAt, "not ended");
        require(campaign.pledged >= campaign.goal, "goal not achieved");
        
        // if not claimed already make it claimed, transfer pledged amount
        require(!campaign.claimed, "claimed");
        campaign.claimed = true;
        token.transfer(msg.sender, campaign.pledged);

        emit Claim(_id);
    }


    // refund function
    function refund(uint _id) external {
        Campaign storage campaign = campaigns[_id];
        
        // campaign must have ended && goald have not reached 
        require(block.timestamp > campaign.endAt, "not ended");
        require(campaign.pledged < campaign.goal, "goal not achieved");
        
        // send balance back to the user
        uint bal = pledgedAmount[_id][msg.sender];
        pledgedAmount[_id][msg.sender] = 0;
        token.transfer(msg.sender, bal);

        // launc refund event
        emit Refund(_id, msg.sender, bal);
    }
}
