export const SSTORE2DataPointer = {
  abi: [
    {
      type: "constructor",
      inputs: [
        {
          name: "_data",
          type: "bytes",
          internalType: "bytes",
        },
      ],
      stateMutability: "nonpayable",
    },
    {
      type: "function",
      name: "pointer",
      inputs: [],
      outputs: [
        {
          name: "",
          type: "address",
          internalType: "address",
        },
      ],
      stateMutability: "view",
    },
  ] as const,
  instances: {
    CHFm: {
      42220: "0x0B04ccAE5d560526fa432DAb790cBF240fAe6c74",
      11142220: "0x4Ec992bf0AC215B77D8f4e169C5ac475d2814D0F",
    },
    GBPm: {
      42220: "0xB4f12C44ec87A4541248BEC6c2D0ce7E7b882694",
      11142220: "0xD54C20d8B8957eb5C44B9880f38B0Ad3d0A86C60",
    },
    JPYm: {
      42220: "0xd9C5a21D81d96DDA1EE1f65fdcAb19fc942E6204",
    },
  } as Record<string, Partial<Record<number, `0x${string}`>>>,
};
