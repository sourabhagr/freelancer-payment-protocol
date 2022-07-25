pragma solidity >=0.4.25 <0.9.0;

interface IERC20 {
    function transfer(address _to, uint256 _value) external returns (bool);
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool);
    function approve(address _spender, uint256 _value) external returns (bool);
}

//TODO: Import contracts like Ownable and add decorators

contract FreelanceContract {

    address payable escrowAddr;
    address payable burnAddr;
    int8 MAX_CONFIRMATION_ATTEMPS_ALLOWED = 5;
    int8 CONTRACT_ACCEPTION_DEADLINE_DAYS = 7;
    IERC20 usdt = IERC20(address(0xdAC17F958D2ee523a2206206994597C13D831ec7));

    enum ContractStatus {CREATED, ACCEPTED_BY_FREELANCER, ACCEPTED_BY_COMPANY, ACCEPTED_BY_BOTH, ASSETS_DELIVERED, EXPIRED_DUE_TO_NON_DELIVERY, ASSETS_ACCEPTED, ASSETS_REJECTED, EXPIRED_DUE_TO_ASSETS_REJECTION, EXPIRED_DUE_TO_NO_CONFIRMATION, EXPIRED_DUE_TO_NO_COMPANY_ACCEPTANCE, EXPIRED_DUE_TO_NO_FREELANCER_ACCEPTANCE}

    struct FContract {
        string deliverables;
        address payable companyAddr;
        address payable freelancerAddr;
        uint256 companyStakedAmt;
        uint256 freelancerStakedAmt;
        uint deliveryDate;
        uint settlementDate;
        ContractStatus state;
        int8 confirmationAttemps;
        uint createdDate;
        string assetsNFTLink;
    }

    FContract[] public fContracts;

    event ContractCreated(string _deliverables, address _companyAddr, address _freelancerAddr, uint256 _companyStakedAmt, uint256 _freelancerStakedAmt, uint _deliveryDelay, uint _settlementDelay, address _createdBy, uint _contractId);
    event StakePostedByCompany(uint _contractId);
    event StakePostedByFreelancer(uint _contractId);
    event ContractAccepted(uint _contractId);
    event DeliverablesUploaded(uint _contractId, address _deliverables);
    event ContractExpiredDueToNoDelivery(uint _contractId, uint _amountTransferedToCompany, uint _amountTransferedToFreelancer);  //TODO: Should we add expiry date in the event?
    event ContractExpiredDueToNoConfirmation(uint _contractId, uint _amountTransferedToCompany, uint _amountTransferedToFreelancer);  //TODO: Should we add expiry date in the event?


    function createFreelancerContract(string memory _deliverables, address payable _companyAddr, address payable _freelancerAddr, uint256 _companyStakedAmt, uint256 _freelancerStakedAmt, uint _deliveryDelay, uint _settlementDelay) public {
        require((msg.sender == _companyAddr) || (msg.sender == _freelancerAddr));
        fContracts.push(FContract(_deliverables, _companyAddr, _freelancerAddr, _companyStakedAmt, _freelancerStakedAmt, _deliveryDelay, _settlementDelay, ContractStatus.CREATED, 0, 0, ""));
        emit ContractCreated(_deliverables, _companyAddr, _freelancerAddr, _companyStakedAmt, _freelancerStakedAmt, _deliveryDelay, _settlementDelay, msg.sender, fContracts.length-1);
    }

    function acceptCompanyPayment(uint contractId) public payable {
        require(msg.sender == fContracts[contractId].companyAddr);
        require(msg.value == fContracts[contractId].companyStakedAmt);
        require((fContracts[contractId].state == ContractStatus.CREATED) || (fContracts[contractId].state == ContractStatus.ACCEPTED_BY_FREELANCER));

        usdt.transfer(escrowAddr, fContracts[contractId].companyStakedAmt);

        if (fContracts[contractId].state == ContractStatus.CREATED) {
            fContracts[contractId].state = ContractStatus.ACCEPTED_BY_COMPANY;
            emit StakePostedByCompany(contractId);
        } else {
            fContracts[contractId].state = ContractStatus.ACCEPTED_BY_BOTH;
            emit StakePostedByCompany(contractId);
            emit ContractAccepted(contractId);
        }
    }

    function acceptFreelancerPayment(uint contractId) public payable {
        require(msg.sender == fContracts[contractId].freelancerAddr);
        require(msg.value == fContracts[contractId].freelancerStakedAmt);
        require((fContracts[contractId].state == ContractStatus.CREATED) || (fContracts[contractId].state == ContractStatus.ACCEPTED_BY_COMPANY));

        usdt.transfer(escrowAddr, fContracts[contractId].freelancerStakedAmt);

        if (fContracts[contractId].state == ContractStatus.CREATED) {
            fContracts[contractId].state = ContractStatus.ACCEPTED_BY_FREELANCER;
            emit StakePostedByFreelancer(contractId);
        } else {
            fContracts[contractId].state = ContractStatus.ACCEPTED_BY_BOTH;
            emit StakePostedByFreelancer(contractId);
            emit ContractAccepted(contractId);
        }
    }

    function returnCompanyStakedAmt(uint contractId) public payable {
        require(msg.sender == fContracts[contractId].companyAddr);
        require(fContracts[contractId].state == ContractStatus.ACCEPTED_BY_COMPANY);
        //TODO: Do below transaction only if called beyond Accepted Date + Deadline
        if (true) {
            usdt.transferFrom(escrowAddr, fContracts[contractId].companyAddr, fContracts[contractId].companyStakedAmt);
            fContracts[contractId].state = ContractStatus.EXPIRED_DUE_TO_NO_FREELANCER_ACCEPTANCE;
        }
    }

    function returnFreelancerStakedAmt(uint contractId) public payable {
        require(msg.sender == fContracts[contractId].freelancerAddr);
        require(fContracts[contractId].state == ContractStatus.ACCEPTED_BY_FREELANCER);
        //TODO: Do below transaction only if called beyond Accepted Date + Deadline
        if (true) {
            usdt.transferFrom(escrowAddr, fContracts[contractId].freelancerAddr, fContracts[contractId].freelancerStakedAmt);
            fContracts[contractId].state = ContractStatus.EXPIRED_DUE_TO_NO_COMPANY_ACCEPTANCE;
        }
    }

    function uploadDeliverables(uint contractId) public {
        require(fContracts[contractId].state == ContractStatus.ACCEPTED_BY_BOTH);
        //TODO: Store the deliverable in a filecoin storage
        //TODO: Mint an NFT out of it
        address nftAddr;
        emit DeliverablesUploaded(contractId, nftAddr);
        fContracts[contractId].state = ContractStatus.ASSETS_DELIVERED;
    }

    //TODO: Currently we are asking the Company to initiate this but explore automation options in future
    function expireContractOverNoDelivery(uint contractId) public {
        require(fContracts[contractId].state == ContractStatus.ACCEPTED_BY_BOTH);
        require(msg.sender == fContracts[contractId].companyAddr);

        //TODO: Do below transaction only if called beyond Delivery Date
        if (true) {
            uint256 companyCompensation = fContracts[contractId].freelancerStakedAmt / 2;
            uint256 stakeToBeBurned = fContracts[contractId].freelancerStakedAmt - companyCompensation;
            //TODO: How are we setting the sender address for this transfer?
            fContracts[contractId].companyAddr.transfer(companyCompensation);
            burnAddr.transfer(stakeToBeBurned);
            fContracts[contractId].companyAddr.transfer(fContracts[contractId].companyStakedAmt);
            fContracts[contractId].state = ContractStatus.EXPIRED_DUE_TO_NON_DELIVERY;
            emit ContractExpiredDueToNoDelivery(contractId, 0, stakeToBeBurned);
        }

    }

    //TODO: Currently we are asking the Freelancer to initiate this but explore automation options in future
    function expiryContractOverNoConfirmation(uint contractId) public {
        require(fContracts[contractId].state == ContractStatus.ASSETS_DELIVERED);
        require(msg.sender == fContracts[contractId].freelancerAddr);

        //TODO: Do below transaction only if called beyond Settlement Date
        if (true) {
            //TODO: How are we setting the sender address for this transfer?
            fContracts[contractId].freelancerAddr.transfer(fContracts[contractId].companyStakedAmt);
            fContracts[contractId].freelancerAddr.transfer(fContracts[contractId].freelancerStakedAmt);

            //TODO: What to do with the delivered NFT?

            fContracts[contractId].state = ContractStatus.EXPIRED_DUE_TO_NO_CONFIRMATION;
        }
    }

    function sendConfirmation(uint contractId, bool _isAccepted) public {
        require(msg.sender == fContracts[contractId].companyAddr);
        require(fContracts[contractId].state == ContractStatus.ASSETS_DELIVERED);
        require(fContracts[contractId].confirmationAttemps < MAX_CONFIRMATION_ATTEMPS_ALLOWED);
        fContracts[contractId].confirmationAttemps += 1;

        if (_isAccepted) {
            //TODO: How are we setting the sender address for this transfer?
            fContracts[contractId].freelancerAddr.transfer(fContracts[contractId].companyStakedAmt);
            fContracts[contractId].freelancerAddr.transfer(fContracts[contractId].freelancerStakedAmt);
            //TODO: Transfer NFT to the company
            fContracts[contractId].state = ContractStatus.ASSETS_ACCEPTED;
        } else {
            if (fContracts[contractId].confirmationAttemps == MAX_CONFIRMATION_ATTEMPS_ALLOWED) {
                fContracts[contractId].state = ContractStatus.EXPIRED_DUE_TO_ASSETS_REJECTION;
                //TODO: How are we setting the sender address for this transfer?
                uint256 freelancerStakeToBeBurnt = fContracts[contractId].freelancerStakedAmt / 2;
                uint256 companyStakeToBeBurnt = fContracts[contractId].freelancerStakedAmt / 2;
                burnAddr.transfer(freelancerStakeToBeBurnt + companyStakeToBeBurnt);
                fContracts[contractId].companyAddr.transfer(fContracts[contractId].companyStakedAmt - companyStakeToBeBurnt);
                fContracts[contractId].freelancerAddr.transfer(fContracts[contractId].freelancerStakedAmt - freelancerStakeToBeBurnt);
            } else {
                //TODO: Update Delivery and Settlement Dates
                fContracts[contractId].state = ContractStatus.ASSETS_REJECTED;
            }
        }
    }
}