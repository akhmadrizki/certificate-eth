// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CertificateManager {
    // 1. ENUMS
    enum CertificateStatus {
        Publish,
        Revoke
    }

    // 2. STRUCTS
    struct Certificate {
        string title;
        string name;
        uint256 issueDate;
        CertificateStatus status;
        uint256 expiredDate;
    }

    // 3. STATE VARIABLES
    // Mapping: Menghubungkan Certificate ID (bytes32) ke Certificate struct
    mapping(bytes32 => Certificate) private certificates;
    
    // Alamat deployer kontrak (hanya orang ini yang bisa menerbitkan sertifikat)
    address public owner;

    // 4. EVENTS
    // Event yang dipancarkan setelah sertifikat berhasil dibuat
    event CertificateIssued(bytes32 indexed certificateId, string title, string recipientName, uint256 issueDate, uint256 expiredDate, address issuer);
    
    // Event yang dipancarkan setelah status sertifikat diubah
    event CertificateStatusUpdated(bytes32 indexed certificateId, CertificateStatus newStatus, address updater);

    // 5. CONSTRUCTOR
    // Fungsi yang dijalankan hanya sekali saat kontrak di-deploy
    constructor() {
        owner = msg.sender;
    }

    // 6. MODIFIER
    // Pembatas agar hanya 'owner' yang bisa menjalankan fungsi ini
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can perform this action.");
        _;
    }

    // 7. FUNCTIONS

    /**
     * @dev Membuat ID unik dari nama penerima dan string acak (nonce)
     * @param _recipientName Nama penerima sertifikat.
     * @param _nonce String unik/acak untuk mencegah duplikasi.
     * @return bytes32 ID sertifikat yang di-hash.
     */
    function generateCertificateId(string memory _recipientName, string memory _nonce) public pure returns (bytes32) {
        // Keccak256 hashing digunakan untuk menghasilkan ID unik.
        return keccak256(abi.encodePacked(_recipientName, _nonce));
    }

    /**
     * @dev Menerbitkan dan menyimpan sertifikat baru ke dalam blockchain.
     * @param _certificateId ID sertifikat unik yang dihasilkan dari fungsi di atas.
     * @param _title Judul sertifikat (contoh: "Workshop HTML").
     * @param _recipientName Nama penerima.
     * @param _expiredDate Tanggal kadaluarsa sertifikat (timestamp).
     */
    function issueCertificate(
        bytes32 _certificateId, 
        string memory _title, 
        string memory _recipientName, 
        uint256 _expiredDate
    ) public onlyOwner {
        // Cek apakah ID sudah ada
        require(bytes(certificates[_certificateId].name).length == 0, "Certificate ID already exists.");
        
        // Cek apakah expired date di masa depan
        require(_expiredDate > block.timestamp, "Expired date must be in the future.");

        // Simpan data sertifikat
        certificates[_certificateId] = Certificate({
            title: _title,
            name: _recipientName,
            issueDate: block.timestamp,
            status: CertificateStatus.Publish,
            expiredDate: _expiredDate
        });

        // Pancarkan Event
        emit CertificateIssued(_certificateId, _title, _recipientName, block.timestamp, _expiredDate, msg.sender);
    }

    /**
     * @dev Mengubah status sertifikat (hanya owner yang bisa).
     * @param _certificateId ID sertifikat yang akan diubah statusnya.
     * @param _newStatus Status baru (Publish atau Revoke).
     */
    function updateCertificateStatus(bytes32 _certificateId, CertificateStatus _newStatus) public onlyOwner {
        // Cek apakah sertifikat ada
        require(bytes(certificates[_certificateId].name).length > 0, "Certificate does not exist.");
        
        // Update status
        certificates[_certificateId].status = _newStatus;
        
        // Pancarkan Event
        emit CertificateStatusUpdated(_certificateId, _newStatus, msg.sender);
    }

    /**
     * @dev Memverifikasi keberadaan sertifikat dan mengembalikan data lengkap. (Fungsi READ ONLY)
     * @param _certificateId ID sertifikat yang akan diverifikasi.
     * @return title Judul sertifikat.
     * @return name Nama penerima.
     * @return issueDate Tanggal diterbitkan.
     * @return status Status sertifikat (Publish/Revoke).
     * @return expiredDate Tanggal kadaluarsa.
     * @return isValid True jika sertifikat valid dan belum kadaluarsa.
     */
    function verifyCertificate(bytes32 _certificateId) public view returns (
        string memory title,
        string memory name,
        uint256 issueDate,
        CertificateStatus status,
        uint256 expiredDate,
        bool isValid
    ) {
        Certificate memory cert = certificates[_certificateId];
        
        // Cek apakah sertifikat ada
        if (bytes(cert.name).length == 0) {
            return ("", "", 0, CertificateStatus.Publish, 0, false);
        }
        
        // Cek apakah sertifikat masih valid (belum kadaluarsa dan status Publish)
        bool isNotExpired = cert.expiredDate > block.timestamp;
        bool isPublished = cert.status == CertificateStatus.Publish;
        
        return (
            cert.title,
            cert.name,
            cert.issueDate,
            cert.status,
            cert.expiredDate,
            isNotExpired && isPublished
        );
    }

    /**
     * @dev Mendapatkan data sertifikat lengkap berdasarkan ID. (Fungsi READ ONLY)
     * @param _certificateId ID sertifikat.
     * @return title Judul sertifikat.
     * @return name Nama penerima.
     * @return issueDate Tanggal diterbitkan.
     * @return status Status sertifikat.
     * @return expiredDate Tanggal kadaluarsa.
     */
    function getCertificate(bytes32 _certificateId) public view returns (
        string memory title,
        string memory name,
        uint256 issueDate,
        CertificateStatus status,
        uint256 expiredDate
    ) {
        require(bytes(certificates[_certificateId].name).length > 0, "Certificate does not exist.");
        Certificate memory cert = certificates[_certificateId];
        return (cert.title, cert.name, cert.issueDate, cert.status, cert.expiredDate);
    }
}