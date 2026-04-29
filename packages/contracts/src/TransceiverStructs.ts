export const TransceiverStructs = {
  abi: [
    {
      type: "function",
      name: "buildAndEncodeTransceiverMessage",
      inputs: [
        {
          name: "prefix",
          type: "bytes4",
          internalType: "bytes4",
        },
        {
          name: "sourceNttManagerAddress",
          type: "bytes32",
          internalType: "bytes32",
        },
        {
          name: "recipientNttManagerAddress",
          type: "bytes32",
          internalType: "bytes32",
        },
        {
          name: "nttManagerMessage",
          type: "bytes",
          internalType: "bytes",
        },
        {
          name: "transceiverPayload",
          type: "bytes",
          internalType: "bytes",
        },
      ],
      outputs: [
        {
          name: "",
          type: "tuple",
          internalType: "struct TransceiverStructs.TransceiverMessage",
          components: [
            {
              name: "sourceNttManagerAddress",
              type: "bytes32",
              internalType: "bytes32",
            },
            {
              name: "recipientNttManagerAddress",
              type: "bytes32",
              internalType: "bytes32",
            },
            {
              name: "nttManagerPayload",
              type: "bytes",
              internalType: "bytes",
            },
            {
              name: "transceiverPayload",
              type: "bytes",
              internalType: "bytes",
            },
          ],
        },
        {
          name: "",
          type: "bytes",
          internalType: "bytes",
        },
      ],
      stateMutability: "pure",
    },
    {
      type: "function",
      name: "decodeTransceiverInit",
      inputs: [
        {
          name: "encoded",
          type: "bytes",
          internalType: "bytes",
        },
      ],
      outputs: [
        {
          name: "init",
          type: "tuple",
          internalType: "struct TransceiverStructs.TransceiverInit",
          components: [
            {
              name: "transceiverIdentifier",
              type: "bytes4",
              internalType: "bytes4",
            },
            {
              name: "nttManagerAddress",
              type: "bytes32",
              internalType: "bytes32",
            },
            {
              name: "nttManagerMode",
              type: "uint8",
              internalType: "uint8",
            },
            {
              name: "tokenAddress",
              type: "bytes32",
              internalType: "bytes32",
            },
            {
              name: "tokenDecimals",
              type: "uint8",
              internalType: "uint8",
            },
          ],
        },
      ],
      stateMutability: "pure",
    },
    {
      type: "function",
      name: "decodeTransceiverRegistration",
      inputs: [
        {
          name: "encoded",
          type: "bytes",
          internalType: "bytes",
        },
      ],
      outputs: [
        {
          name: "registration",
          type: "tuple",
          internalType: "struct TransceiverStructs.TransceiverRegistration",
          components: [
            {
              name: "transceiverIdentifier",
              type: "bytes4",
              internalType: "bytes4",
            },
            {
              name: "transceiverChainId",
              type: "uint16",
              internalType: "uint16",
            },
            {
              name: "transceiverAddress",
              type: "bytes32",
              internalType: "bytes32",
            },
          ],
        },
      ],
      stateMutability: "pure",
    },
    {
      type: "function",
      name: "encodeNativeTokenTransfer",
      inputs: [
        {
          name: "m",
          type: "tuple",
          internalType: "struct TransceiverStructs.NativeTokenTransfer",
          components: [
            {
              name: "amount",
              type: "uint72",
              internalType: "TrimmedAmount",
            },
            {
              name: "sourceToken",
              type: "bytes32",
              internalType: "bytes32",
            },
            {
              name: "to",
              type: "bytes32",
              internalType: "bytes32",
            },
            {
              name: "toChain",
              type: "uint16",
              internalType: "uint16",
            },
            {
              name: "additionalPayload",
              type: "bytes",
              internalType: "bytes",
            },
          ],
        },
      ],
      outputs: [
        {
          name: "encoded",
          type: "bytes",
          internalType: "bytes",
        },
      ],
      stateMutability: "pure",
    },
    {
      type: "function",
      name: "encodeNttManagerMessage",
      inputs: [
        {
          name: "m",
          type: "tuple",
          internalType: "struct TransceiverStructs.NttManagerMessage",
          components: [
            {
              name: "id",
              type: "bytes32",
              internalType: "bytes32",
            },
            {
              name: "sender",
              type: "bytes32",
              internalType: "bytes32",
            },
            {
              name: "payload",
              type: "bytes",
              internalType: "bytes",
            },
          ],
        },
      ],
      outputs: [
        {
          name: "encoded",
          type: "bytes",
          internalType: "bytes",
        },
      ],
      stateMutability: "pure",
    },
    {
      type: "function",
      name: "encodeTransceiverInit",
      inputs: [
        {
          name: "init",
          type: "tuple",
          internalType: "struct TransceiverStructs.TransceiverInit",
          components: [
            {
              name: "transceiverIdentifier",
              type: "bytes4",
              internalType: "bytes4",
            },
            {
              name: "nttManagerAddress",
              type: "bytes32",
              internalType: "bytes32",
            },
            {
              name: "nttManagerMode",
              type: "uint8",
              internalType: "uint8",
            },
            {
              name: "tokenAddress",
              type: "bytes32",
              internalType: "bytes32",
            },
            {
              name: "tokenDecimals",
              type: "uint8",
              internalType: "uint8",
            },
          ],
        },
      ],
      outputs: [
        {
          name: "",
          type: "bytes",
          internalType: "bytes",
        },
      ],
      stateMutability: "pure",
    },
    {
      type: "function",
      name: "encodeTransceiverInstruction",
      inputs: [
        {
          name: "instruction",
          type: "tuple",
          internalType: "struct TransceiverStructs.TransceiverInstruction",
          components: [
            {
              name: "index",
              type: "uint8",
              internalType: "uint8",
            },
            {
              name: "payload",
              type: "bytes",
              internalType: "bytes",
            },
          ],
        },
      ],
      outputs: [
        {
          name: "",
          type: "bytes",
          internalType: "bytes",
        },
      ],
      stateMutability: "pure",
    },
    {
      type: "function",
      name: "encodeTransceiverInstructions",
      inputs: [
        {
          name: "instructions",
          type: "tuple[]",
          internalType: "struct TransceiverStructs.TransceiverInstruction[]",
          components: [
            {
              name: "index",
              type: "uint8",
              internalType: "uint8",
            },
            {
              name: "payload",
              type: "bytes",
              internalType: "bytes",
            },
          ],
        },
      ],
      outputs: [
        {
          name: "",
          type: "bytes",
          internalType: "bytes",
        },
      ],
      stateMutability: "pure",
    },
    {
      type: "function",
      name: "encodeTransceiverMessage",
      inputs: [
        {
          name: "prefix",
          type: "bytes4",
          internalType: "bytes4",
        },
        {
          name: "m",
          type: "tuple",
          internalType: "struct TransceiverStructs.TransceiverMessage",
          components: [
            {
              name: "sourceNttManagerAddress",
              type: "bytes32",
              internalType: "bytes32",
            },
            {
              name: "recipientNttManagerAddress",
              type: "bytes32",
              internalType: "bytes32",
            },
            {
              name: "nttManagerPayload",
              type: "bytes",
              internalType: "bytes",
            },
            {
              name: "transceiverPayload",
              type: "bytes",
              internalType: "bytes",
            },
          ],
        },
      ],
      outputs: [
        {
          name: "encoded",
          type: "bytes",
          internalType: "bytes",
        },
      ],
      stateMutability: "pure",
    },
    {
      type: "function",
      name: "encodeTransceiverRegistration",
      inputs: [
        {
          name: "registration",
          type: "tuple",
          internalType: "struct TransceiverStructs.TransceiverRegistration",
          components: [
            {
              name: "transceiverIdentifier",
              type: "bytes4",
              internalType: "bytes4",
            },
            {
              name: "transceiverChainId",
              type: "uint16",
              internalType: "uint16",
            },
            {
              name: "transceiverAddress",
              type: "bytes32",
              internalType: "bytes32",
            },
          ],
        },
      ],
      outputs: [
        {
          name: "",
          type: "bytes",
          internalType: "bytes",
        },
      ],
      stateMutability: "pure",
    },
    {
      type: "function",
      name: "nttManagerMessageDigest",
      inputs: [
        {
          name: "sourceChainId",
          type: "uint16",
          internalType: "uint16",
        },
        {
          name: "m",
          type: "tuple",
          internalType: "struct TransceiverStructs.NttManagerMessage",
          components: [
            {
              name: "id",
              type: "bytes32",
              internalType: "bytes32",
            },
            {
              name: "sender",
              type: "bytes32",
              internalType: "bytes32",
            },
            {
              name: "payload",
              type: "bytes",
              internalType: "bytes",
            },
          ],
        },
      ],
      outputs: [
        {
          name: "",
          type: "bytes32",
          internalType: "bytes32",
        },
      ],
      stateMutability: "pure",
    },
    {
      type: "function",
      name: "parseNativeTokenTransfer",
      inputs: [
        {
          name: "encoded",
          type: "bytes",
          internalType: "bytes",
        },
      ],
      outputs: [
        {
          name: "nativeTokenTransfer",
          type: "tuple",
          internalType: "struct TransceiverStructs.NativeTokenTransfer",
          components: [
            {
              name: "amount",
              type: "uint72",
              internalType: "TrimmedAmount",
            },
            {
              name: "sourceToken",
              type: "bytes32",
              internalType: "bytes32",
            },
            {
              name: "to",
              type: "bytes32",
              internalType: "bytes32",
            },
            {
              name: "toChain",
              type: "uint16",
              internalType: "uint16",
            },
            {
              name: "additionalPayload",
              type: "bytes",
              internalType: "bytes",
            },
          ],
        },
      ],
      stateMutability: "pure",
    },
    {
      type: "function",
      name: "parseNttManagerMessage",
      inputs: [
        {
          name: "encoded",
          type: "bytes",
          internalType: "bytes",
        },
      ],
      outputs: [
        {
          name: "nttManagerMessage",
          type: "tuple",
          internalType: "struct TransceiverStructs.NttManagerMessage",
          components: [
            {
              name: "id",
              type: "bytes32",
              internalType: "bytes32",
            },
            {
              name: "sender",
              type: "bytes32",
              internalType: "bytes32",
            },
            {
              name: "payload",
              type: "bytes",
              internalType: "bytes",
            },
          ],
        },
      ],
      stateMutability: "pure",
    },
    {
      type: "function",
      name: "parseTransceiverAndNttManagerMessage",
      inputs: [
        {
          name: "expectedPrefix",
          type: "bytes4",
          internalType: "bytes4",
        },
        {
          name: "payload",
          type: "bytes",
          internalType: "bytes",
        },
      ],
      outputs: [
        {
          name: "",
          type: "tuple",
          internalType: "struct TransceiverStructs.TransceiverMessage",
          components: [
            {
              name: "sourceNttManagerAddress",
              type: "bytes32",
              internalType: "bytes32",
            },
            {
              name: "recipientNttManagerAddress",
              type: "bytes32",
              internalType: "bytes32",
            },
            {
              name: "nttManagerPayload",
              type: "bytes",
              internalType: "bytes",
            },
            {
              name: "transceiverPayload",
              type: "bytes",
              internalType: "bytes",
            },
          ],
        },
        {
          name: "",
          type: "tuple",
          internalType: "struct TransceiverStructs.NttManagerMessage",
          components: [
            {
              name: "id",
              type: "bytes32",
              internalType: "bytes32",
            },
            {
              name: "sender",
              type: "bytes32",
              internalType: "bytes32",
            },
            {
              name: "payload",
              type: "bytes",
              internalType: "bytes",
            },
          ],
        },
      ],
      stateMutability: "pure",
    },
    {
      type: "function",
      name: "parseTransceiverInstructionChecked",
      inputs: [
        {
          name: "encoded",
          type: "bytes",
          internalType: "bytes",
        },
      ],
      outputs: [
        {
          name: "instruction",
          type: "tuple",
          internalType: "struct TransceiverStructs.TransceiverInstruction",
          components: [
            {
              name: "index",
              type: "uint8",
              internalType: "uint8",
            },
            {
              name: "payload",
              type: "bytes",
              internalType: "bytes",
            },
          ],
        },
      ],
      stateMutability: "pure",
    },
    {
      type: "function",
      name: "parseTransceiverInstructionUnchecked",
      inputs: [
        {
          name: "encoded",
          type: "bytes",
          internalType: "bytes",
        },
        {
          name: "offset",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      outputs: [
        {
          name: "instruction",
          type: "tuple",
          internalType: "struct TransceiverStructs.TransceiverInstruction",
          components: [
            {
              name: "index",
              type: "uint8",
              internalType: "uint8",
            },
            {
              name: "payload",
              type: "bytes",
              internalType: "bytes",
            },
          ],
        },
        {
          name: "nextOffset",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      stateMutability: "pure",
    },
    {
      type: "function",
      name: "parseTransceiverInstructions",
      inputs: [
        {
          name: "encoded",
          type: "bytes",
          internalType: "bytes",
        },
        {
          name: "numRegisteredTransceivers",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      outputs: [
        {
          name: "",
          type: "tuple[]",
          internalType: "struct TransceiverStructs.TransceiverInstruction[]",
          components: [
            {
              name: "index",
              type: "uint8",
              internalType: "uint8",
            },
            {
              name: "payload",
              type: "bytes",
              internalType: "bytes",
            },
          ],
        },
      ],
      stateMutability: "pure",
    },
    {
      type: "error",
      name: "IncorrectPrefix",
      inputs: [
        {
          name: "prefix",
          type: "bytes4",
          internalType: "bytes4",
        },
      ],
    },
    {
      type: "error",
      name: "InvalidInstructionIndex",
      inputs: [
        {
          name: "providedIndex",
          type: "uint256",
          internalType: "uint256",
        },
        {
          name: "numTransceivers",
          type: "uint256",
          internalType: "uint256",
        },
      ],
    },
    {
      type: "error",
      name: "LengthMismatch",
      inputs: [
        {
          name: "encodedLength",
          type: "uint256",
          internalType: "uint256",
        },
        {
          name: "expectedLength",
          type: "uint256",
          internalType: "uint256",
        },
      ],
    },
    {
      type: "error",
      name: "PayloadTooLong",
      inputs: [
        {
          name: "size",
          type: "uint256",
          internalType: "uint256",
        },
      ],
    },
    {
      type: "error",
      name: "UnorderedInstructions",
      inputs: [
        {
          name: "lastIndex",
          type: "uint256",
          internalType: "uint256",
        },
        {
          name: "instructionIndex",
          type: "uint256",
          internalType: "uint256",
        },
      ],
    },
  ] as const,
  address: {
    143: "0x7C2420401eB6bEB50501Fd5bc8b60DBfC2b0dEF0",
    42220: "0x7C2420401eB6bEB50501Fd5bc8b60DBfC2b0dEF0",
  } as Partial<Record<number, `0x${string}`>>,
};
