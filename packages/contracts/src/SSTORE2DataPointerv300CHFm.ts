export const SSTORE2DataPointerv300CHFm = {
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
  address: {
    42220: "0x0B04ccAE5d560526fa432DAb790cBF240fAe6c74",
    11142220: "0x4Ec992bf0AC215B77D8f4e169C5ac475d2814D0F",
  } as Partial<Record<number, `0x${string}`>>,
};
