from typing import List
from Crypto.Cipher import ChaCha20
import sys
from pathlib import Path

DEF_NUM_BLOCKS = int(sys.argv[1])
DEF_TDATA_WIDTH = int(sys.argv[2])
DEF_NUMBIGBLOCKS = int(sys.argv[3])

# Number of 512-bit blocks processed at once in the core
NUMBER_OF_BLOCKS = DEF_NUM_BLOCKS

def hexdump(data, bytes_per_line=16):
    """
    Pretty prints a hexdump of a bytes object.
    
    Args:
        data: A bytes object to hexdump.
        bytes_per_line: Number of bytes to display per line. Defaults to 16.
    """
    address = 0
    while address < len(data):
        line = data[address:address+bytes_per_line]
        hex_chars = [f'{byte:02X}' for byte in line]
        hex_string = ' '.join(hex_chars)
        ascii_string = ''.join([chr(byte) if 32 <= byte <= 126 else '.' for byte in line])
        print(f'{address:08X}: {hex_string:<48} {ascii_string}')
        address += bytes_per_line

def write_systemverilog_value(name: str, array: bytes):
    hex_string = array[::-1].hex()
    sys.stdout.write(f"reg [{len(array*8)-1}:0] {name} = {len(array)*8}'h{hex_string};\n")

def read_systemverilog_value(value_str: str):
    spl = value_str.split("'h")
    return bytes.fromhex(spl[1])[::-1]

def write_rust_array(name: str, array: bytes):
    s = ", ".join([hex(x) for x in array])
    #sys.stdout.write(f"let {name}: [u8; {len(array)}] = [{s}];\n")

def to_little_endian_hex(byte_array):
    hex_string = ""
    for i in range(0, len(byte_array), 4):
        value = int.from_bytes(byte_array[i:i+4], byteorder='little')
        hex_string += format(value, '08x') + "\n"
    return hex_string

def write_test_file(file_path: Path, bytes_to_write: bytes):
    to_write = to_little_endian_hex(bytes_to_write)
    file_path.write_text(to_write)

import os

def generate_random_bits(bit_length: int):
    """
    Generate random bytes of a given bit length.
    
    Args:
        bit_length (int): The length of the random bytes in bits.
        
    Returns:
        bytes: A string of random bytes.
    """
    byte_length = (bit_length // 8)
    return os.urandom(byte_length)

def test_chacha20(testpass: int):
    print(f"*** Creating files for test pass ***")
    print(f"DEF_NUM_BLOCKS: {DEF_NUM_BLOCKS}")
    print(f"DEF_TDATA_WIDTH: {DEF_TDATA_WIDTH}")
    print(f"="*80)
    out_folder = Path("./test_files/")
    out_folder.mkdir(parents=True, exist_ok=True)

    
    key_b = generate_random_bits(256)
    assert len(key_b) == 32
    
    print("Key:")
    hexdump(key_b)

    write_test_file(Path(out_folder) / "key", key_b)
    
    iv_b = generate_random_bits(96)
    assert len(iv_b) == 12

    print("IV:")
    hexdump(iv_b)

    write_test_file(Path(out_folder) / "iv", iv_b)

    plaintext_b = generate_random_bits(512 * NUMBER_OF_BLOCKS * DEF_NUMBIGBLOCKS)
    assert len(plaintext_b) >= 64

    write_test_file(Path(out_folder) / "plaintext", plaintext_b)
    print("Plaintext:")
    hexdump(plaintext_b)

    cipher = ChaCha20.new(key=key_b, nonce=iv_b)
    ciphertext = cipher.encrypt(plaintext_b)

    write_test_file(Path(out_folder) / "ciphertext", ciphertext)
    print("Ciphertext:")
    hexdump(ciphertext)
    
    write_systemverilog_value("key", key_b)
    write_systemverilog_value("iv", iv_b)
    write_systemverilog_value("input_plaintext", plaintext_b)
    write_systemverilog_value("expected_ciphertext", ciphertext)

    print(f"="*80)

test_chacha20(1)
