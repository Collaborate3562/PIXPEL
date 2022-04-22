async function main() {
  // Grab the contract factory 

  // Start deployment, returning a promise that resolves to a contract object

  // const MyNFT = await ethers.getContractFactory("OdinMarketplace");

  // const arg1 = "0x59FF98B80254794d48b571e37c2E17581B8bA2f7"; // NFT Address
  // const arg2 = "0x53569a6E822Af3B11137be68e2f944Ae18832aDD"; // paymentAddress
  // const arg3 = "0x53569a6E822Af3B11137be68e2f944Ae18832aDD"; // payoutAddress
  // const arg4 = "0x7747276E8C5dc926655c2B5a70C9d51BdC6a2F7C"; // Token Address
  // const arg5 = "0xA9cc497e49A0D168b3Bb7F1C5d4b4e44932B33a4"; // Development Address

  // const myNFT = await MyNFT.deploy(arg1, arg2, arg3, arg4, arg5); // Instance of the contract 

  // const MyNFT = await ethers.getContractFactory("Odin");

  // const arg1 = "0xE6416A2d592779D1341Fd18695Ed98Fad90cD60B"; // NFT Address
  // const arg2 = "0xd99d1c33f9fc3444f8101754abc46c52416550d1"; // PancakeRouter Address
  // const arg3 = "0x5754284f345afc66a98fbb0a0afe71e0f007b949"; // USDT Address
  // const arg4 = "0x0000000000000000000000000000000000000000"; // Staking Address
  // const arg5 = 9647382007;

  // const myNFT = await MyNFT.deploy(arg1, arg2, arg3, arg4, arg5); // Instance of the contract 

  // const MyNFT = await ethers.getContractFactory("OdinNFTStaking");

  // const arg1 = "0x31Eb05a97Fab382A76e5E87Bf1Be3E3B5EF21d47"; // NFT Address
  // const arg2 = "0x7747276E8C5dc926655c2B5a70C9d51BdC6a2F7C"; // Token Address
  // const arg3 = "0x53569a6E822Af3B11137be68e2f944Ae18832aDD"; // Adminrecovery Address

  // const myNFT = await MyNFT.deploy(arg1, arg2, arg3); // Instance of the contract 

  const MyNFT = await ethers.getContractFactory("EliteFoxesClub");

  const arg1 = "123"; // NFT Address
  const arg2 = "123"; // Token Address

  const myNFT = await MyNFT.deploy(arg1, arg2); // Instance of the contract 

  console.log("Contract deployed to address:", myNFT.address);
}

main()
 .then(() => process.exit(0))
 .catch(error => {
   console.error(error);
   process.exit(1);
 });