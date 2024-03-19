const express = require("express");
const { ethers } = require("ethers");
const { abi } = require("./bidding.json");
require("dotenv").config();

const app = express();
app.use(express.json());

const provider = new ethers.JsonRpcProvider(
  "https://nodeapi.test.energi.network/v1/jsonrpc"
);
const signer_1 = new ethers.Wallet(process.env.PRIVATE_KEY_1, provider);
const signer_2 = new ethers.Wallet(process.env.PRIVATE_KEY_2, provider);
const signer_3 = new ethers.Wallet(process.env.PRIVATE_KEY_3, provider);

app.post("/bid", async (req, res) => {
  let bidding;
  switch (req.body.userNumber) {
    case "1":
      bidding = new ethers.Contract(
        "0x1d370423be52f9424b11163162F78f2e912C4907",
        abi,
        signer_1
      );
      break;
    case "2":
      bidding = new ethers.Contract(
        "0x1d370423be52f9424b11163162F78f2e912C4907",
        abi,
        signer_2
      );
      break;
    case "3":
      bidding = new ethers.Contract(
        "0x1d370423be52f9424b11163162F78f2e912C4907",
        abi,
        signer_3
      );
      break;
    default:
      res.send("unknown user");
  }
  const { amount } = req.body;
  const tx = await bidding.bid({ value: amount, gasLimit: 1000000 });
  await tx.wait();

  console.log("hash is ", tx.hash);

  res.send("bidding successful. tx hash: ", tx.hash);
});

app.listen(3000, () => {
  console.log(`Bidding war listening on port 3000`);
});
