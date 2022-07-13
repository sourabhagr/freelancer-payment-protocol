pragma solidity >=0.4.25 <0.9.0;

contract FreelanceContract {

    address payable escrowAddr;
    address payable burnAddr;
    int8 MAX_CONFIRMATION_ATTEMPS_ALLOWED = 5;

    struct FContract {
        string deliverables;
        address payable companyAddr;
        address payable freelancerAddr;
        uint32 companyStakedAmt;
        uint32 freelancerStakedAmt;
        uint deliveryDate;
        uint settlementDate;
        int8 state; //TODO: Create enum for states
        int8 confirmationAttemps;
    }

    FContract[] public fContracts;

    function createFreelancerContract(string memory _deliverables, address payable _companyAddr, address payable _freelancerAddr, uint32 _companyStakedAmt, uint32 _freelancerStakedAmt, uint _deliveryDelay, uint _settlementDelay) public {
        require((msg.sender == _companyAddr) || (msg.sender == _freelancerAddr));
        fContracts.push(FContract(_deliverables, _companyAddr, _freelancerAddr, _companyStakedAmt, _freelancerStakedAmt, _deliveryDelay, _settlementDelay, 0, 0));
    }

    function acceptCompanyPayment(uint contractId) public payable {
        require(msg.sender == fContracts[contractId].companyAddr);
        require(msg.value == fContracts[contractId].companyStakedAmt);
        require((fContracts[contractId].state == 0) || (fContracts[contractId].state == 2));

        escrowAddr.transfer(fContracts[contractId].companyStakedAmt);

        if (fContracts[contractId].state == 0) {
            fContracts[contractId].state = 1;
        } else {
            fContracts[contractId].state = 3;
        }
    }

    function acceptFreelancerPayment(uint contractId) public payable {
        require(msg.sender == fContracts[contractId].freelancerAddr);
        require(msg.value == fContracts[contractId].freelancerStakedAmt);
        require((fContracts[contractId].state == 0) || (fContracts[contractId].state == 1));

        escrowAddr.transfer(fContracts[contractId].freelancerStakedAmt);

        if (fContracts[contractId].state == 0) {
            fContracts[contractId].state = 2;
        } else {
            fContracts[contractId].state = 3;
        }
    }

    function uploadDeliverables(uint contractId) public {
        require(fContracts[contractId].state == 3);
        //TODO: Store the deliverable in a filecoin storage
        //TODO: Mint an NFT out of it
        fContracts[contractId].state = 4;
    }

    //TODO: How will this function be called?
    function expireContractOverNoDelivery(uint contractId) public {
        require(fContracts[contractId].state == 3);
        require(msg.sender == escrowAddr);

        //TODO: How are we setting the sender address for this transfer?
        fContracts[contractId].companyAddr.transfer(fContracts[contractId].companyStakedAmt);
        fContracts[contractId].companyAddr.transfer(fContracts[contractId].freelancerStakedAmt / 2);
        burnAddr.transfer(fContracts[contractId].freelancerStakedAmt / 2);

        fContracts[contractId].state = -3;
    }

    //TODO: How will this function be called?
    function expiryContractOverNoConfirmation(uint contractId) public {
        require(fContracts[contractId].state == 4);
        require(msg.sender == escrowAddr);

        //TODO: How are we setting the sender address for this transfer?
        fContracts[contractId].freelancerAddr.transfer(fContracts[contractId].companyStakedAmt);
        fContracts[contractId].freelancerAddr.transfer(fContracts[contractId].freelancerStakedAmt);

        //TODO: What to do with the delivered NFT?

        fContracts[contractId].state = -4;
    }

    function sendConfirmation(uint contractId, bool _isAccepted) public {
        require(msg.sender == fContracts[contractId].companyAddr);
        require(fContracts[contractId].state == 4);
        require(fContracts[contractId].confirmationAttemps < MAX_CONFIRMATION_ATTEMPS_ALLOWED);
        fContracts[contractId].confirmationAttemps += 1;

        if (_isAccepted) {
            //TODO: How are we setting the sender address for this transfer?
            fContracts[contractId].freelancerAddr.transfer(fContracts[contractId].companyStakedAmt);
            fContracts[contractId].freelancerAddr.transfer(fContracts[contractId].freelancerStakedAmt);
            //TODO: Transfer NFT to the company
            fContracts[contractId].state = -5;
        } else {
            if (fContracts[contractId].confirmationAttemps == MAX_CONFIRMATION_ATTEMPS_ALLOWED) {
                fContracts[contractId].state = -6;
                //TODO: How are we setting the sender address for this transfer?
                burnAddr.transfer(fContracts[contractId].freelancerStakedAmt / 2);
                burnAddr.transfer(fContracts[contractId].freelancerStakedAmt / 2);
                //TODO: Decimal handling when divided by 2?
                fContracts[contractId].companyAddr.transfer(fContracts[contractId].companyStakedAmt - fContracts[contractId].freelancerStakedAmt / 2);
                fContracts[contractId].freelancerAddr.transfer(fContracts[contractId].freelancerStakedAmt / 2);
            } else {
                //TODO: Update Delivery and Settlement Dates
                fContracts[contractId].state = 6;
            }
        }
    }
}