async function main() {
  // Grab the contract factory 

  const MyNFT = await ethers.getContractFactory("PixpelNFT");

  const myNFT = await MyNFT.deploy();

  console.log("Contract deployed to address:", myNFT.address);
}

main()
 .then(() => process.exit(0))
 .catch(error => {
   console.error(error);
   process.exit(1);
 });