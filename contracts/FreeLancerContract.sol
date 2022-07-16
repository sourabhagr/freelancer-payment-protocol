pragma solidity >=0.4.25 <0.9.0;

contract FreelanceContract {

    address payable escrowAddr;
    address payable burnAddr;
    int8 MAX_CONFIRMATION_ATTEMPS_ALLOWED = 5;

    enum ContractStatus {CREATED, ACCEPTED_BY_FREELANCER, ACCEPTED_BY_COMPANY, ACCEPTED_BY_BOTH, ASSETS_DELIVERED, EXPIRED_DUE_TO_NON_DELIVERY, ASSETS_ACCEPTED, ASSETS_REJECTED, EXPIRED_DUE_TO_ASSETS_REJECTION, EXPIRED_DUE_TO_NO_CONFIRMATION}

    struct FContract {
        string deliverables;
        address payable companyAddr;
        address payable freelancerAddr;
        uint32 companyStakedAmt;
        uint32 freelancerStakedAmt;
        uint deliveryDate;
        uint settlementDate;
        ContractStatus state;
        int8 confirmationAttemps;
    }

    FContract[] public fContracts;

    function createFreelancerContract(string memory _deliverables, address payable _companyAddr, address payable _freelancerAddr, uint32 _companyStakedAmt, uint32 _freelancerStakedAmt, uint _deliveryDelay, uint _settlementDelay) public {
        require((msg.sender == _companyAddr) || (msg.sender == _freelancerAddr));
        fContracts.push(FContract(_deliverables, _companyAddr, _freelancerAddr, _companyStakedAmt, _freelancerStakedAmt, _deliveryDelay, _settlementDelay, ContractStatus.CREATED, 0));
    }

    function acceptCompanyPayment(uint contractId) public payable {
        require(msg.sender == fContracts[contractId].companyAddr);
        require(msg.value == fContracts[contractId].companyStakedAmt);
        require((fContracts[contractId].state == ContractStatus.CREATED) || (fContracts[contractId].state == ContractStatus.ACCEPTED_BY_FREELANCER));

        escrowAddr.transfer(fContracts[contractId].companyStakedAmt);

        if (fContracts[contractId].state == ContractStatus.CREATED) {
            fContracts[contractId].state = ContractStatus.ACCEPTED_BY_COMPANY;
        } else {
            fContracts[contractId].state = ContractStatus.ACCEPTED_BY_BOTH;
        }
    }

    function acceptFreelancerPayment(uint contractId) public payable {
        require(msg.sender == fContracts[contractId].freelancerAddr);
        require(msg.value == fContracts[contractId].freelancerStakedAmt);
        require((fContracts[contractId].state == ContractStatus.CREATED) || (fContracts[contractId].state == ContractStatus.ACCEPTED_BY_COMPANY));

        escrowAddr.transfer(fContracts[contractId].freelancerStakedAmt);

        if (fContracts[contractId].state == ContractStatus.CREATED) {
            fContracts[contractId].state = ContractStatus.ACCEPTED_BY_FREELANCER;
        } else {
            fContracts[contractId].state = ContractStatus.ACCEPTED_BY_BOTH;
        }
    }

    function uploadDeliverables(uint contractId) public {
        require(fContracts[contractId].state == ContractStatus.ACCEPTED_BY_BOTH);
        //TODO: Store the deliverable in a filecoin storage
        //TODO: Mint an NFT out of it
        fContracts[contractId].state = ContractStatus.ASSETS_DELIVERED;
    }

    //TODO: Currently we are asking the Company to initiate this but explore automation options in future
    function expireContractOverNoDelivery(uint contractId) public {
        require(fContracts[contractId].state == ContractStatus.ACCEPTED_BY_BOTH);
        require(msg.sender == fContracts[contractId].companyAddr);

        //TODO: Do below transaction only if called beyond Delivery Date
        if (true) {
            uint32 companyCompensation = fContracts[contractId].freelancerStakedAmt / 2;
            uint32 stakeToBeBurned = fContracts[contractId].freelancerStakedAmt - companyCompensation;
            //TODO: How are we setting the sender address for this transfer?
            fContracts[contractId].companyAddr.transfer(companyCompensation);
            burnAddr.transfer(stakeToBeBurned);
            fContracts[contractId].companyAddr.transfer(fContracts[contractId].companyStakedAmt);
            fContracts[contractId].state = ContractStatus.EXPIRED_DUE_TO_NON_DELIVERY;
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
                uint32 freelancerStakeToBeBurnt = fContracts[contractId].freelancerStakedAmt / 2;
                uint32 companyStakeToBeBurnt = fContracts[contractId].freelancerStakedAmt / 2;
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