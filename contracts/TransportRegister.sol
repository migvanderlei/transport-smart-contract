// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.7;

/**
 * @title Storage
 * @dev Store & retrieve value in a variable
 * @custom:dev-run-script ./scripts/deploy_with_ethers.ts
 */
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/Strings.sol";

contract TransportRegister {
        
    address public owner;

    // usado para gerar hashes dos pacotes
    uint256 public packagesCount;

    // struct básica de endereço
    struct StreetAddress {
        string name;
        string district;
        string city;
        string state;
        string number;
        string complement;
    }

    enum PackageStatus{ PROCESSING, TRANSPORTING, DELIVERED, CANCELLED }

    struct Package {
        string packageId;
        string description;
        address sender;
        address receiver;
        StreetAddress deliveryAddress;
        PackageStatus status;
        uint createdDate;
        uint lastUpdatedDate; 
        bool exists;
    }

    // DTO de entrada do pacote
    struct PackageData {
        string description;
        StreetAddress deliveryAddress;
    }

    // DTO do status do pacote
    struct PackageStatusDTO {
        string statusMessage;
        PackageStatus status;
        uint createdDate;
        uint lastUpdatedDate;
    }

    // Mappings
 
    mapping(address =>  string[]) sendersPackages;

    mapping(string => Package) packagesIndex;

    mapping(uint => string) statusMessages;

    //  Modifiers

    modifier isSender(string calldata packageId) {
        bool result = false;
        string[] memory packagesList = sendersPackages[msg.sender];

        for (uint i=0; i < packagesList.length; i++) {
            if (keccak256(bytes(packageId)) == keccak256(bytes(packagesList[i]))) {
                result = true;
                break;
            }
        }

        require(result , "Somente o remetente do pacote pode executar essa operacao!");
        _;
    }
    
    constructor () {
        owner = msg.sender;

        statusMessages[0] = "Em processamento";
        statusMessages[1] = "Em transporte";
        statusMessages[2] = "Entregue";
        statusMessages[3] = "Cancelado";

        packagesCount = 0;
    }

    // função que gera hash de id para um pacote com base no endereço do remetente e de um número sequencial
    function getPackageHashId(address senderAddress, uint256 number) private pure returns (string memory) {
        uint rand = uint(keccak256(abi.encodePacked(senderAddress, number)));
        return Strings.toString(rand);
    }

    // registrar um novo pacote, torna o sender da mensagem o remetente do pacote
    function registerPackage (PackageData calldata packageData, address receiver) public {
        
        // novo id
        string memory packageHashId = getPackageHashId(msg.sender, packagesCount);
        
        // objeto do pacote
        Package memory newPackage = Package({
            packageId: packageHashId,
            description: packageData.description,
            sender: msg.sender,
            receiver: receiver,
            deliveryAddress: packageData.deliveryAddress,
            status: PackageStatus.PROCESSING,
            createdDate: block.timestamp,
            lastUpdatedDate: block.timestamp,
            exists: true
        });

        // relaciona o rementente com o id do pacote        
        sendersPackages[msg.sender].push(packageHashId);

        // adiciona o pacote ao indice
        packagesIndex[packageHashId] = newPackage;

        packagesCount += 1;
    }

    function getPackage(string calldata packageId) public view isSender(packageId) returns (Package memory) {
        Package memory package = packagesIndex[packageId];

        // retorna o pacote inteiro
        if (package.exists) {
            return package;
        }

        revert("Not found");
    } 

    function getPackageStatus(string calldata packageId) public view isSender(packageId) returns (PackageStatusDTO memory){
        Package memory package = packagesIndex[packageId];
 
        // retorna o ultimo endereco registrado e o status do pacote como completo ou em rota
        if (package.exists) {
            return PackageStatusDTO({
                status: package.status,
                statusMessage: statusMessages[uint(package.status)],
                createdDate: package.createdDate,
                lastUpdatedDate: package.lastUpdatedDate
            });
        }

        revert("Not found");
    } 

    // atualiza a rota do pacote
    function updatePackageStatus(string calldata packageId, uint newStatus) public isSender(packageId) {
        Package storage package = packagesIndex[packageId];

        // atualiza e salva
        if (package.exists) {
            if (newStatus == 0) {
                package.status = PackageStatus.PROCESSING;
            } else {
                if (newStatus == 1) {
                    package.status = PackageStatus.TRANSPORTING;
                } else {
                    if (newStatus == 2) {
                        package.status = PackageStatus.DELIVERED;
                    } else {
                        if (newStatus == 3) {
                            package.status = PackageStatus.CANCELLED;
                        } else {
                            revert("Invalid status");
                        }
                    }
                }
            }

            package.lastUpdatedDate == block.timestamp;
        } else {
            revert("Not found");
        }


    } 

    // retorna todos os pacotes enviados pelo sender da mensagem
    function listMySentPackages() public view returns (Package[] memory) {
        string[] memory packagesIds = sendersPackages[msg.sender];

        if (packagesIds.length > 0) {
            Package[] memory packages = new Package[](packagesIds.length);
            for (uint i=0; i < packagesIds.length; i++) {
                Package memory package = packagesIndex[packagesIds[i]];
                
                packages[i] = package;
            }

            return packages;
        }

        revert("No packages sent found");
    }

}
