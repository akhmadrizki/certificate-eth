// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CertificateManager {
    // 1. ENUMS
    enum CertificateStatus {
        Publish,
        Revoke
    }

    // 2. STRUCTS
    
    // STRUCT BARU: Mewakili satu peserta
    struct Participant {
        string name;
        uint256 nim;
    }

    // STRUCT UTAMA: Data Sertifikat
    struct Certificate {
        string title;
        uint256 issueDate;
        CertificateStatus status;
        uint256 expiredDate;
        // Menyimpan array dari struct Participant
        Participant[] participants; 
    }

    // 3. STATE VARIABLES
    // Mapping 1: Menghubungkan Certificate ID (bytes32) ke Certificate struct
    mapping(bytes32 => Certificate) private certificates;
    
    // Mapping 2: Menghubungkan NIM (uint256) ke Certificate ID (bytes32)
    mapping(uint256 => bytes32) private nimToCertificateId; 
    
    // Alamat deployer kontrak
    address public owner;

    // 4. EVENTS
    // Event yang dipancarkan setelah sertifikat berhasil dibuat
    event CertificateIssued(
        bytes32 indexed certificateId, 
        string title, 
        uint256 issueDate, 
        uint256 expiredDate, 
        uint256 numberOfParticipants, 
        address issuer
    );
    
    // Event yang dipancarkan setelah status sertifikat diubah
    event CertificateStatusUpdated(bytes32 indexed certificateId, CertificateStatus newStatus, address updater);

    // 5. CONSTRUCTOR
    constructor() {
        owner = msg.sender;
    }

    // 6. MODIFIER
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can perform this action.");
        _;
    }

    // 7. FUNCTIONS

    /**
     * @dev Membuat ID unik dari judul dan string acak (nonce)
     */
    function generateCertificateId(string memory _title, string memory _nonce) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_title, _nonce));
    }

    /**
     * @dev Menerbitkan dan menyimpan sertifikat baru dengan array peserta.
     * MENGGUNAKAN LOOP MANUAL untuk menghindari UnimplementedFeatureError.
     */
    function issueCertificate(
        bytes32 _certificateId, 
        string memory _title, 
        Participant[] memory _participants,
        uint256 _expiredDate
    ) public onlyOwner {
        // Cek apakah ID sertifikat sudah ada
        require(bytes(certificates[_certificateId].title).length == 0, "Certificate ID already exists.");
        // Pastikan ada peserta
        require(_participants.length > 0, "At least one participant is required.");
        // Cek apakah expired date di masa depan
        require(_expiredDate > block.timestamp, "Expired date must be in the future.");

        // Inisialisasi referensi sertifikat baru di storage
        Certificate storage newCert = certificates[_certificateId];
        
        // Simpan field dasar
        newCert.title = _title;
        newCert.issueDate = block.timestamp;
        newCert.status = CertificateStatus.Publish;
        newCert.expiredDate = _expiredDate;

        // Iterasi dan simpan peserta (Solusi Non-viaIR)
        for (uint i = 0; i < _participants.length; i++) {
            uint256 currentNIM = _participants[i].nim;
            
            require(currentNIM != 0, "NIM cannot be zero.");
            // Cek duplikasi NIM dalam batch yang sama (disarankan)
            for (uint j = i + 1; j < _participants.length; j++) {
                require(_participants[j].nim != currentNIM, "Duplicate NIM found in participants array.");
            }
            // Cek apakah NIM sudah terdaftar di mapping global
            require(nimToCertificateId[currentNIM] == 0, "NIM/Random Number already registered with another certificate."); 
            
            // Simpan Participant ke array storage
            newCert.participants.push(_participants[i]);
            
            // Daftarkan NIM ke ID sertifikat ini
            nimToCertificateId[currentNIM] = _certificateId;
        }

        // Pancarkan Event
        emit CertificateIssued(_certificateId, _title, block.timestamp, _expiredDate, _participants.length, msg.sender);
    }

    /**
     * @dev Mengubah status sertifikat (hanya owner yang bisa).
     */
    function updateCertificateStatus(bytes32 _certificateId, CertificateStatus _newStatus) public onlyOwner {
        // Cek apakah sertifikat ada
        require(bytes(certificates[_certificateId].title).length > 0, "Certificate does not exist.");
        
        // Update status
        certificates[_certificateId].status = _newStatus;
        
        // Pancarkan Event
        emit CertificateStatusUpdated(_certificateId, _newStatus, msg.sender);
    }
    
    /**
     * @dev Memverifikasi keberadaan sertifikat berdasarkan NIM/Angka Unik. (Fungsi READ ONLY)
     */
    function verifyCertificateByNIM(uint256 _nimOrRandomNumber) public view returns (
        string memory title,
        uint256 issueDate,
        CertificateStatus status,
        uint256 expiredDate,
        string memory participantName,
        bool isValid
    ) {
        // Dapatkan ID sertifikat dari NIM
        bytes32 certId = nimToCertificateId[_nimOrRandomNumber];

        // Cek apakah NIM terdaftar / sertifikat ada
        if (certId == 0) {
            return ("", 0, CertificateStatus.Publish, 0, "", false);
        }
        
        // Menggunakan 'storage' untuk menghindari biaya gas berlebihan saat menyalin array besar
        Certificate storage cert = certificates[certId]; 
        
        // Cek apakah sertifikat masih valid (belum kadaluarsa dan status Publish)
        bool isNotExpired = cert.expiredDate > block.timestamp;
        bool isPublished = cert.status == CertificateStatus.Publish;

        // Cari nama peserta yang sesuai dengan NIM (memerlukan loop)
        string memory foundName = "";
        for(uint i = 0; i < cert.participants.length; i++) {
            if (cert.participants[i].nim == _nimOrRandomNumber) {
                foundName = cert.participants[i].name;
                break;
            }
        }
        
        return (
            cert.title,
            cert.issueDate,
            cert.status,
            cert.expiredDate,
            foundName,
            isNotExpired && isPublished
        );
    }

    /**
     * @dev Mendapatkan data sertifikat lengkap berdasarkan ID. (Fungsi READ ONLY)
     */
    function getCertificate(bytes32 _certificateId) public view returns (
        string memory title,
        uint256 issueDate,
        CertificateStatus status,
        uint256 expiredDate,
        Participant[] memory participants
    ) {
        // Cek apakah sertifikat ada (menggunakan title sebagai penanda)
        require(bytes(certificates[_certificateId].title).length > 0, "Certificate does not exist.");
        
        // Menggunakan 'storage' untuk mengakses data
        Certificate storage cert = certificates[_certificateId];
        
        // Catatan: Compiler modern (0.8.0+) dapat mengembalikan array dari storage ke memory,
        // tetapi fungsi ini akan mahal jika arraynya sangat besar.
        return (cert.title, cert.issueDate, cert.status, cert.expiredDate, cert.participants);
    }
}