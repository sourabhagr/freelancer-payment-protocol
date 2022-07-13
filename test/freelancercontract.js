const FreeLancerContract = artifacts.require("FreeLancerContract");

contract('FreeLancerContract', (accounts) => {

    it("should be able to create a new contract", async () => {
        const contractInstance = await FreeLancerContract.new();
        const accountOne = accounts[0];
        const accountTwo = accounts[1];
        //TODO: Set correct delivery and settlement dates
        const result = await contractInstance.createFreelancerContract("Test", accountOne, accountTwo, 10, 1, 0, 0, {from: accountOne});
        expect(result.receipt.status).to.equal(true);
        expect(result.logs[0].args.state).to.equal(0);
    });
});
