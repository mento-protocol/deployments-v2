export const CollateralRegistry = {
  abi: [
    {
      type: "constructor",
      inputs: [
        {
          name: "_boldToken",
          type: "address",
          internalType: "contract IBoldToken",
        },
        {
          name: "_tokens",
          type: "address[]",
          internalType: "contract IERC20Metadata[]",
        },
        {
          name: "_troveManagers",
          type: "address[]",
          internalType: "contract ITroveManager[]",
        },
        {
          name: "_systemParams",
          type: "address",
          internalType: "contract ISystemParams",
        },
        {
          name: "_liquidityStrategy",
          type: "address",
          internalType: "address",
        },
      ],
      stateMutability: "nonpayable",
    },
    {
      type: "function",
      name: "baseRate",
      inputs: [],
      outputs: [
        {
          name: "",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "boldToken",
      inputs: [],
      outputs: [
        {
          name: "",
          type: "address",
          internalType: "contract IBoldToken",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "getEffectiveRedemptionFeeInBold",
      inputs: [
        {
          name: "_redeemAmount",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      outputs: [
        {
          name: "",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "getRedemptionFeeWithDecay",
      inputs: [
        {
          name: "_ETHDrawn",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      outputs: [
        {
          name: "",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "getRedemptionRate",
      inputs: [],
      outputs: [
        {
          name: "",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "getRedemptionRateForRedeemedAmount",
      inputs: [
        {
          name: "_redeemAmount",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      outputs: [
        {
          name: "",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "getRedemptionRateWithDecay",
      inputs: [],
      outputs: [
        {
          name: "",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "getToken",
      inputs: [
        {
          name: "_index",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      outputs: [
        {
          name: "",
          type: "address",
          internalType: "contract IERC20Metadata",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "getTroveManager",
      inputs: [
        {
          name: "_index",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      outputs: [
        {
          name: "",
          type: "address",
          internalType: "contract ITroveManager",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "lastFeeOperationTime",
      inputs: [],
      outputs: [
        {
          name: "",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "liquidityStrategy",
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
    {
      type: "function",
      name: "redeemCollateral",
      inputs: [
        {
          name: "_boldAmount",
          type: "uint256",
          internalType: "uint256",
        },
        {
          name: "_maxIterationsPerCollateral",
          type: "uint256",
          internalType: "uint256",
        },
        {
          name: "_maxFeePercentage",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      outputs: [],
      stateMutability: "nonpayable",
    },
    {
      type: "function",
      name: "redeemCollateralRebalancing",
      inputs: [
        {
          name: "_boldAmount",
          type: "uint256",
          internalType: "uint256",
        },
        {
          name: "_maxIterationsPerCollateral",
          type: "uint256",
          internalType: "uint256",
        },
        {
          name: "_troveOwnerFee",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      outputs: [],
      stateMutability: "nonpayable",
    },
    {
      type: "function",
      name: "systemParams",
      inputs: [],
      outputs: [
        {
          name: "",
          type: "address",
          internalType: "contract ISystemParams",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "totalCollaterals",
      inputs: [],
      outputs: [
        {
          name: "",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "event",
      name: "BaseRateUpdated",
      inputs: [
        {
          name: "_baseRate",
          type: "uint256",
          indexed: false,
          internalType: "uint256",
        },
      ],
      anonymous: false,
    },
    {
      type: "event",
      name: "LastFeeOpTimeUpdated",
      inputs: [
        {
          name: "_lastFeeOpTime",
          type: "uint256",
          indexed: false,
          internalType: "uint256",
        },
      ],
      anonymous: false,
    },
    {
      type: "event",
      name: "LiquidityStrategyUpdated",
      inputs: [
        {
          name: "_liquidityStrategy",
          type: "address",
          indexed: true,
          internalType: "address",
        },
      ],
      anonymous: false,
    },
  ] as const,
  address: {
    42220: "0x1bEDD4334335522B0a0e8e610d326B16B0a605Fb",
    11142220: "0xc674b6562eaf4E40056aad628E398F58cA0b2B91",
  } as Partial<Record<number, `0x${string}`>>,
};
