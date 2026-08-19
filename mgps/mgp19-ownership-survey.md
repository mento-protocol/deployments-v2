<!-- markdownlint-disable MD013 -->

# Celo mainnet — issuance vs. DEX/DAO ownership survey

Snapshot taken at Celo block **75138312** (2026-08-18) from `treb ls -n celo -s mainnet`, `.treb/addressbook.json`, the Celo core Registry (`0x…ce10`) and live RPC reads (`owner()`, Celo-proxy `_getOwner()`, EIP-1967 admin slot, `ProxyAdmin.owner()`). This is the evidence base for **MGP-19** (`script/migration/MGP19.sol`, `mgps/mgp19.md`).

Holders: **Mento timelock** = `0x890DB8A597940165901372Dd7DB61C9f246e2147` (Mento Governance), **Migration multisig** = `0x58099B74F4ACd642Da77b4B7966b4138ec5Ba458` (Mento Labs 4/6 Safe, rights entrusted in MGP-14/16), **Celo Governance** = `0xD533Ca259b330c7A88f74E000a3FaEa2d63B7972`.

## A. Core issuance → transferred to Celo Governance by MGP-19

Stable assets, the direct reserve mint/burn path (Broker/BiPoolManager/Reserve), V3 reserve issuance (ReserveV2 + strategies that mint/burn against it), the CDP branches, and the oracle layer that gates minting/burning. Every right below is held either by the Mento timelock (→ Mento Governance proposal leg) or by the migration multisig (→ multisig batch leg). Exception: the ChainlinkRelayerFactory ProxyAdmin is owned by a legacy Mento Labs Safe and is a manual follow-up.

| Contract                 | Address                                      | Proxy admin / ProxyAdmin owner | Contract owner     |
| ------------------------ | -------------------------------------------- | ------------------------------ | ------------------ |
| BRLm                     | `0xe8537a3d056DA446677B9E9d6c5dB704EaAb4787` | Mento timelock                 | Mento timelock     |
| XOFm                     | `0x73F93dcc49cB8A239e2032663e9475dd5ef29A08` | Mento timelock                 | Mento timelock     |
| KESm                     | `0x456a3D042C0DbD3db53D5489e98dFb038553B0d0` | Mento timelock                 | Mento timelock     |
| PHPm                     | `0x105d4A9306D2E55a71d2Eb95B81553AE1dC20d7B` | Mento timelock                 | Mento timelock     |
| COPm                     | `0x8A567e2aE79CA692Bd748aB832081C45de4041eA` | Mento timelock                 | Mento timelock     |
| GHSm                     | `0xfAeA5F3404bbA20D3cc2f8C4B0A888F55a3c7313` | Mento timelock                 | Mento timelock     |
| ZARm                     | `0x4c35853A3B4e647fD266f4de678dCc8fEC410BF6` | Mento timelock                 | Mento timelock     |
| CADm                     | `0xff4Ab19391af240c311c54200a492233052B6325` | Mento timelock                 | Mento timelock     |
| AUDm                     | `0x7175504C455076F15c04A2F90a8e352281F492F9` | Mento timelock                 | Mento timelock     |
| NGNm                     | `0xE2702Bd97ee33c88c8f6f92DA3B733608aa76F71` | Mento timelock                 | Mento timelock     |
| USDm                     | `0x765DE816845861e75A25fCA122bb6898B8B1282a` | Migration multisig             | Migration multisig |
| EURm                     | `0xD8763CBa276a3738E6DE85b4b3bF5FDed6D6cA73` | Migration multisig             | Migration multisig |
| GBPm                     | `0xCCF663b1fF11028f0b19058d0f7B674004a40746` | Migration multisig             | Migration multisig |
| CHFm                     | `0xb55a79F398E759E43C95b979163f30eC87Ee131D` | Migration multisig             | Migration multisig |
| JPYm                     | `0xc45eCF20f3CD864B32D9794d6f76814aE8892e20` | Migration multisig             | Migration multisig |
| Broker                   | `0x777A8255cA72412f0d706dc03C9D1987306B4CaD` | Mento timelock                 | Mento timelock     |
| BiPoolManager            | `0x22d9db95E6Ae61c104A7B6F6C78D7993B94ec901` | Mento timelock                 | Migration multisig |
| Reserve (v1)             | `0x9380fA34Fd9e4Fd14c06305fd7B6199089eD4eb9` | Mento timelock                 | Mento timelock     |
| SortedOracles            | `0xefB84935239dAcdecF7c5bA76d8dE40b077B7b33` | Mento timelock                 | Migration multisig |
| BreakerBox               | `0x303ED1df62Fa067659B586EbEe8De0EcE824Ab39` | —                              | Migration multisig |
| MedianDeltaBreaker       | `0x49349F92D2B17d491e42C8fdB02D19f072F9B5D9` | —                              | Migration multisig |
| ValueDeltaBreaker        | `0x4DBC33B3abA78475A5AA4BC7A5B11445d387BF68` | —                              | Migration multisig |
| ChainlinkRelayerFactory  | `0x247Cb6ECf21bDd2Bc29d726CcCC8d2F066211663` | Legacy Mento Labs Safe (3/8)   | Migration multisig |
| ReserveV2                | `0x4255Cf38e51516766180b33122029A88Cb853806` | Migration multisig             | Migration multisig |
| ReserveLiquidityStrategy | `0xa0fB8b16ce6AF3634fF9F3f4F40E49E1C1ae4f0B` | Migration multisig             | Migration multisig |
| CDPLiquidityStrategy     | `0x4e78BD9565341EAbe99cDC024acB044d9BDcB985` | Migration multisig             | Migration multisig |
| ReserveTroveFactory      | `0x02859465DCC7D7F2Bee183fC7FaC78544c9519e1` | —                              | Migration multisig |
| FXPriceFeed GBPm         | `0xBBB144A67f4403112b4C895Cc85d5EE4F90013DE` | Migration multisig             | Migration multisig |
| FXPriceFeed CHFm         | `0x8a94073809E9Ae55626c2FD413826bF93f755a73` | Migration multisig             | Migration multisig |
| FXPriceFeed JPYm         | `0x8409587c8BA4f6850AEE09A32B86022C3E88AD33` | Migration multisig             | Migration multisig |
| SystemParams GBPm        | `0x70536e44d1D9238BA8E35Ffe63Bb388a63F0DE51` | Migration multisig             | —                  |
| SystemParams CHFm        | `0xe604507642469bE4699FeBDf4A701D9A104dd173` | Migration multisig             | —                  |
| SystemParams JPYm        | `0xC7829C5D1701aB366D248ca384C4caefD87EcDF1` | Migration multisig             | —                  |
| StabilityPool GBPm       | `0x06346c0fAB682dBde9f245D2D84677592E8aaa15` | Migration multisig             | —                  |
| StabilityPool CHFm       | `0xc415cA43aB6Ab246E64559696b8DCAcdd08A39e8` | Migration multisig             | —                  |
| StabilityPool JPYm       | `0x62A519b4D0693E976b78b195E34a548BcF1D2355` | Migration multisig             | —                  |

## B. Mento FX DEX → stays with Mento Governance / Mento Labs

FPMM-based DEX and its adapters. `OracleAdapter` is shared with the CDP FXPriceFeeds (which can be re-pointed by their owner) — flagged in mgp19.md as a follow-up.

| Contract                     | Address                                      | Proxy admin / ProxyAdmin owner | Contract owner     |
| ---------------------------- | -------------------------------------------- | ------------------------------ | ------------------ |
| FPMMFactory                  | `0xa849b475FE5a4B5C9C3280152c7a1945b907613b` | Migration multisig             | Migration multisig |
| FactoryRegistry              | `0x7b2f7d11eabD576782f77bF2CcA46a853410AdF6` | Migration multisig             | Migration multisig |
| OpenLiquidityStrategy        | `0x54e2Ae8c8448912E17cE0b2453bAFB7B0D80E40f` | Migration multisig             | Migration multisig |
| OracleAdapter                | `0xa472fBBF4b890A54381977ac392BdF82EeC4383a` | Migration multisig             | Migration multisig |
| OracleAdapterCollateral      | `0xEB23E1339b2119c0f4a0097Cb294E990C1fA6423` | Migration multisig             | Migration multisig |
| VirtualPoolFactory           | `0x22abd4ADF6aab38aC1022352d496A07Acee5aCB3` | —                              | Migration multisig |
| MarketHoursBreakerToggleable | `0x411e0876750eE59d7D7C131e2d1F0b1a71d2ef44` | —                              | Migration multisig |
| Router                       | `0x4861840C2EfB2b98312B0aE34d86fD73E8f9B6f6` | —                              | —                  |

## C. Mento DAO → stays with Mento Governance

| Contract                        | Address                                      | Proxy admin / ProxyAdmin owner | Contract owner            |
| ------------------------------- | -------------------------------------------- | ------------------------------ | ------------------------- |
| MentoGovernor                   | `0x47036d78bB3169b4F5560dD77BF93f4412A59852` | Mento timelock                 | —                         |
| TimelockController              | `0x890DB8A597940165901372Dd7DB61C9f246e2147` | Mento timelock                 | —                         |
| Locking                         | `0x001Bb66636dCd149A1A2bA8C50E408BdDd80279C` | Mento timelock                 | Mento timelock            |
| ProxyAdmin (governance proxies) | `0x70d8DC60f9701c46D4CE9AC141E154f6804e1dC3` | —                              | Mento timelock            |
| MENTO token                     | `0x7FF62f59e3e89EA34163EA1458EEBCc81177Cfb6` | (not part of this survey)      | (not part of this survey) |

## D. Immutable / ownerless (nothing to transfer)

Per CDP branch (GBPm, CHFm, JPYm): AddressesRegistry (ownership renounced after `setAddresses`), BorrowerOperations, TroveManager, ActivePool, DefaultPool, CollSurplusPool, GasPool, SortedTroves, TroveNFT, MetadataNFT, HintHelpers, MultiTroveGetter, CollateralRegistry, FixedAssetReader, SSTORE2DataPointer. Mento V2: ConstantSumPricingModule, ConstantProductPricingModule. V3: FPMM implementation, MarketHoursBreaker (non-toggleable), NttDeployHelpers, TransceiverStructs library. Implementation contracts (StableTokenV2/V3, BiPoolManagerFeeSetter, …) are not proxies and their own `Ownable` state is irrelevant.

## E. External / not Mento-governed

CELO (Celo Governance), USDC, USDT, axlUSDC, axlEUROC (issuers), WormholeCoreBridge, L2SequencerUptimeFeed (owner is an external EOA), Celo core Registry entries `Exchange*`/`GrandaMento` (removed).

## Notes

- Celo core Registry still maps `Reserve`, `StableToken`, `StableTokenEUR`, `StableTokenBRL`, `StableTokenXOF`, `SortedOracles` to the addresses above; the Registry itself is owned by Celo Governance.
- `ReserveLiquidityStrategy` holds minter/burner roles on USDm (verified on-chain), i.e. it is a direct reserve mint/burn path — hence issuance. `OpenLiquidityStrategy` never mints — hence DEX.
- MGP-18 (forum, 2026-08-17) lowers V2 trading limits (governance) and has the migration multisig deprecate six V2 exchanges through the BiPoolManager; MGP-19's multisig batch must run after those operations.
- Ordering: `src/ProposalDependencyGuard.sol` (deployed via CREATE3 by the MGP-19 script when `dependsOnProposalId` is set) makes MGP-19's governance leg revert while MGP-18 is Pending/Active/Succeeded/Queued, so both proposals can be voted on concurrently while execution order is enforced on-chain.
