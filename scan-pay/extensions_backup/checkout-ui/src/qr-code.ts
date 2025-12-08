/* eslint-disable */
// Type definitions for qrcode.js
// Project: https://github.com/davidshimjs/qrcodejs
// Definitions by: DirtyCajunRice <https://github.com/DirtyCajunRice>
// Definitions: https://github.com/DefinitelyTyped/DefinitelyTyped

//
// Updated to be a self-contained TypeScript module without DOM dependencies.
//

enum QRMode {
    MODE_NUMBER = 1 << 0,
    MODE_ALPHA_NUM = 1 << 1,
    MODE_8BIT_BYTE = 1 << 2,
    MODE_KANJI = 1 << 3
}

enum QRErrorCorrectLevel {
    L = 1,
    M = 0,
    Q = 3,
    H = 2
}

const QRUtil = {
    getBCHTypeInfo: (data: number): number => {
        let d = data << 10;
        while (QRUtil.getBCHDigit(d) - QRUtil.getBCHDigit(0x1335) >= 0) {
            d ^= (0x1335 << (QRUtil.getBCHDigit(d) - QRUtil.getBCHDigit(0x1335)));
        }
        return ((data << 10) | d) ^ 0x5412;
    },
    getBCHTypeNumber: (data: number): number => {
        let d = data << 12;
        while (QRUtil.getBCHDigit(d) - QRUtil.getBCHDigit(0x7973) >= 0) {
            d ^= (0x7973 << (QRUtil.getBCHDigit(d) - QRUtil.getBCHDigit(0x7973)));
        }
        return (data << 12) | d;
    },
    getBCHDigit: (data: number): number => {
        let digit = 0;
        while (data != 0) {
            digit++;
            data >>>= 1;
        }
        return digit;
    },
    getPatternPosition: (typeNumber: number): number[] => {
        return QR_PATTERN_POSITION_TABLE[typeNumber - 1];
    },
    getMask: (maskPattern: number, i: number, j: number): boolean => {
        switch (maskPattern) {
            case 0: return (i + j) % 2 == 0;
            case 1: return i % 2 == 0;
            case 2: return j % 3 == 0;
            case 3: return (i + j) % 3 == 0;
            case 4: return (Math.floor(i / 2) + Math.floor(j / 3)) % 2 == 0;
            case 5: return (i * j) % 2 + (i * j) % 3 == 0;
            case 6: return ((i * j) % 2 + (i * j) % 3) % 2 == 0;
            case 7: return ((i * j) % 3 + (i + j) % 2) % 2 == 0;
            default: throw new Error("bad maskPattern:" + maskPattern);
        }
    },
    getErrorCorrectPolynomial: (errorCorrectLength: number): QRPolynomial => {
        let a = new QRPolynomial([1], 0);
        for (let i = 0; i < errorCorrectLength; i++) {
            a = a.multiply(new QRPolynomial([1, QRMath.gexp(i)], 0));
        }
        return a;
    },
    getLengthInBits: (mode: QRMode, type: number): number => {
        if (1 <= type && type < 10) {
            switch (mode) {
                case QRMode.MODE_NUMBER: return 10;
                case QRMode.MODE_ALPHA_NUM: return 9;
                case QRMode.MODE_8BIT_BYTE: return 8;
                case QRMode.MODE_KANJI: return 8;
                default: throw new Error("mode:" + mode);
            }
        } else if (type < 27) {
            switch (mode) {
                case QRMode.MODE_NUMBER: return 12;
                case QRMode.MODE_ALPHA_NUM: return 11;
                case QRMode.MODE_8BIT_BYTE: return 16;
                case QRMode.MODE_KANJI: return 10;
                default: throw new Error("mode:" + mode);
            }
        } else if (type < 41) {
            switch (mode) {
                case QRMode.MODE_NUMBER: return 14;
                case QRMode.MODE_ALPHA_NUM: return 13;
                case QRMode.MODE_8BIT_BYTE: return 16;
                case QRMode.MODE_KANJI: return 12;
                default: throw new Error("mode:" + mode);
            }
        } else {
            throw new Error("type:" + type);
        }
    },
    getLostPoint: (qrcode: QRCodeModel): number => {
        const moduleCount = qrcode.getModuleCount();
        let lostPoint = 0;
        for (let row = 0; row < moduleCount; row++) {
            for (let col = 0; col < moduleCount; col++) {
                let sameCount = 0;
                const dark = qrcode.isDark(row, col);
                for (let r = -1; r <= 1; r++) {
                    if (row + r < 0 || moduleCount <= row + r) continue;
                    for (let c = -1; c <= 1; c++) {
                        if (col + c < 0 || moduleCount <= col + c) continue;
                        if (r == 0 && c == 0) continue;
                        if (dark == qrcode.isDark(row + r, col + c)) sameCount++;
                    }
                }
                if (sameCount > 5) lostPoint += (3 + sameCount - 5);
            }
        }
        for (let row = 0; row < moduleCount - 1; row++) {
            for (let col = 0; col < moduleCount - 1; col++) {
                let count = 0;
                if (qrcode.isDark(row, col)) count++;
                if (qrcode.isDark(row + 1, col)) count++;
                if (qrcode.isDark(row, col + 1)) count++;
                if (qrcode.isDark(row + 1, col + 1)) count++;
                if (count == 0 || count == 4) lostPoint += 3;
            }
        }
        for (let row = 0; row < moduleCount; row++) {
            for (let col = 0; col < moduleCount - 6; col++) {
                if (qrcode.isDark(row, col) && !qrcode.isDark(row, col + 1) && qrcode.isDark(row, col + 2) && qrcode.isDark(row, col + 3) && qrcode.isDark(row, col + 4) && !qrcode.isDark(row, col + 5) && qrcode.isDark(row, col + 6)) {
                    lostPoint += 40;
                }
            }
        }
        for (let col = 0; col < moduleCount; col++) {
            for (let row = 0; row < moduleCount - 6; row++) {
                if (qrcode.isDark(row, col) && !qrcode.isDark(row + 1, col) && qrcode.isDark(row + 2, col) && qrcode.isDark(row + 3, col) && qrcode.isDark(row + 4, col) && !qrcode.isDark(row + 5, col) && qrcode.isDark(row + 6, col)) {
                    lostPoint += 40;
                }
            }
        }
        let darkCount = 0;
        for (let col = 0; col < moduleCount; col++) {
            for (let row = 0; row < moduleCount; row++) {
                if (qrcode.isDark(row, col)) darkCount++;
            }
        }
        const ratio = Math.abs(100 * darkCount / moduleCount / moduleCount - 50) / 5;
        lostPoint += ratio * 10;
        return lostPoint;
    }
};

const QRMath = {
    glog: (n: number): number => {
        if (n < 1) throw new Error("glog(" + n + ")");
        return LOG_TABLE[n];
    },
    gexp: (n: number): number => {
        while (n < 0) n += 255;
        while (n >= 256) n -= 255;
        return EXP_TABLE[n];
    }
};

class QRPolynomial {
    num: number[];

    constructor(num: number[], shift: number) {
        if (num.length == 0) throw new Error("NPE");
        let offset = 0;
        while (offset < num.length && num[offset] == 0) offset++;
        this.num = new Array(num.length - offset + shift);
        for (let i = 0; i < num.length - offset; i++) {
            this.num[i] = num[i + offset];
        }
    }

    get(index: number): number {
        return this.num[index];
    }

    getLength(): number {
        return this.num.length;
    }

    multiply(e: QRPolynomial): QRPolynomial {
        const num = new Array(this.getLength() + e.getLength() - 1);
        for (let i = 0; i < this.getLength(); i++) {
            for (let j = 0; j < e.getLength(); j++) {
                num[i + j] ^= QRMath.gexp(QRMath.glog(this.get(i)) + QRMath.glog(e.get(j)));
            }
        }
        return new QRPolynomial(num, 0);
    }

    mod(e: QRPolynomial): QRPolynomial {
        if (this.getLength() - e.getLength() < 0) return this;
        const ratio = QRMath.glog(this.get(0)) - QRMath.glog(e.get(0));
        const num = new Array(this.getLength());
        for (let i = 0; i < this.getLength(); i++) num[i] = this.get(i);
        for (let i = 0; i < e.getLength(); i++) num[i] ^= QRMath.gexp(QRMath.glog(e.get(i)) + ratio);
        return new QRPolynomial(num, 0).mod(e);
    }
}

class QR8bitByte {
    mode = QRMode.MODE_8BIT_BYTE;
    data: string;
    parsedData: number[] = [];

    constructor(data: string) {
        this.data = data;
        for (let i = 0, l = this.data.length; i < l; i++) {
            const code = this.data.charCodeAt(i);
            if (code > 0x10000) {
                this.parsedData.push(((code >> 18) & 0x07) | 0xF0);
                this.parsedData.push(((code >> 12) & 0x3F) | 0x80);
                this.parsedData.push(((code >> 6) & 0x3F) | 0x80);
                this.parsedData.push((code & 0x3F) | 0x80);
            } else if (code > 0x800) {
                this.parsedData.push(((code >> 12) & 0x0F) | 0xE0);
                this.parsedData.push(((code >> 6) & 0x3F) | 0x80);
                this.parsedData.push((code & 0x3F) | 0x80);
            } else if (code > 0x80) {
                this.parsedData.push(((code >> 6) & 0x1F) | 0xC0);
                this.parsedData.push((code & 0x3F) | 0x80);
            } else {
                this.parsedData.push(code);
            }
        }
    }

    getLength(): number {
        return this.parsedData.length;
    }

    write(buffer: QRBitBuffer): void {
        for (let i = 0; i < this.parsedData.length; i++) {
            buffer.put(this.parsedData[i], 8);
        }
    }
}

class QRCodeModel {
    typeNumber: number;
    errorCorrectLevel: QRErrorCorrectLevel;
    modules: (boolean | null)[][] = [];
    moduleCount = 0;
    dataCache: number[] = [];
    dataList: QR8bitByte[] = [];

    constructor(typeNumber: number, errorCorrectLevel: QRErrorCorrectLevel) {
        this.typeNumber = typeNumber;
        this.errorCorrectLevel = errorCorrectLevel;
    }

    addData(data: string): void {
        const newData = new QR8bitByte(data);
        this.dataList.push(newData);
        this.dataCache = [];
    }

    isDark(row: number, col: number): boolean {
        if (row < 0 || this.moduleCount <= row || col < 0 || this.moduleCount <= col) {
            throw new Error(row + "," + col);
        }
        return this.modules[row][col] || false;
    }

    getModuleCount(): number {
        return this.moduleCount;
    }

    make(): void {
        this.makeImpl(false, this.getBestMaskPattern());
    }

    makeImpl(test: boolean, maskPattern: number): void {
        this.moduleCount = this.typeNumber * 4 + 17;
        this.modules = new Array(this.moduleCount);
        for (let row = 0; row < this.moduleCount; row++) {
            this.modules[row] = new Array(this.moduleCount);
            for (let col = 0; col < this.moduleCount; col++) {
                this.modules[row][col] = null;
            }
        }
        this.setupPositionProbePattern(0, 0);
        this.setupPositionProbePattern(this.moduleCount - 7, 0);
        this.setupPositionProbePattern(0, this.moduleCount - 7);
        this.setupPositionAdjustPattern();
        this.setupTimingPattern();
        this.setupTypeInfo(test, maskPattern);
        if (this.typeNumber >= 7) {
            this.setupTypeNumber(test);
        }
        if (this.dataCache.length == 0) {
            this.dataCache = QRCodeModel.createData(this.typeNumber, this.errorCorrectLevel, this.dataList);
        }
        this.mapData(this.dataCache, maskPattern);
    }

    setupPositionProbePattern(row: number, col: number): void {
        for (let r = -1; r <= 7; r++) {
            if (row + r <= -1 || this.moduleCount <= row + r) continue;
            for (let c = -1; c <= 7; c++) {
                if (col + c <= -1 || this.moduleCount <= col + c) continue;
                if ((0 <= r && r <= 6 && (c == 0 || c == 6)) || (0 <= c && c <= 6 && (r == 0 || r == 6)) || (2 <= r && r <= 4 && 2 <= c && c <= 4)) {
                    this.modules[row + r][col + c] = true;
                } else {
                    this.modules[row + r][col + c] = false;
                }
            }
        }
    }

    getBestMaskPattern(): number {
        let minLostPoint = 0;
        let pattern = 0;
        for (let i = 0; i < 8; i++) {
            this.makeImpl(true, i);
            const lostPoint = QRUtil.getLostPoint(this);
            if (i == 0 || minLostPoint > lostPoint) {
                minLostPoint = lostPoint;
                pattern = i;
            }
        }
        return pattern;
    }

    setupTimingPattern(): void {
        for (let r = 8; r < this.moduleCount - 8; r++) {
            if (this.modules[r][6] != null) continue;
            this.modules[r][6] = (r % 2 == 0);
        }
        for (let c = 8; c < this.moduleCount - 8; c++) {
            if (this.modules[6][c] != null) continue;
            this.modules[6][c] = (c % 2 == 0);
        }
    }

    setupPositionAdjustPattern(): void {
        const pos = QRUtil.getPatternPosition(this.typeNumber);
        for (let i = 0; i < pos.length; i++) {
            for (let j = 0; j < pos.length; j++) {
                const row = pos[i];
                const col = pos[j];
                if (this.modules[row][col] != null) continue;
                for (let r = -2; r <= 2; r++) {
                    for (let c = -2; c <= 2; c++) {
                        if (r == -2 || r == 2 || c == -2 || c == 2 || (r == 0 && c == 0)) {
                            this.modules[row + r][col + c] = true;
                        } else {
                            this.modules[row + r][col + c] = false;
                        }
                    }
                }
            }
        }
    }

    setupTypeNumber(test: boolean): void {
        const bits = QRUtil.getBCHTypeNumber(this.typeNumber);
        for (let i = 0; i < 18; i++) {
            const mod = (!test && ((bits >> i) & 1) == 1);
            this.modules[Math.floor(i / 3)][i % 3 + this.moduleCount - 8 - 3] = mod;
        }
        for (let i = 0; i < 18; i++) {
            const mod = (!test && ((bits >> i) & 1) == 1);
            this.modules[i % 3 + this.moduleCount - 8 - 3][Math.floor(i / 3)] = mod;
        }
    }

    setupTypeInfo(test: boolean, maskPattern: number): void {
        const data = (this.errorCorrectLevel << 3) | maskPattern;
        const bits = QRUtil.getBCHTypeInfo(data);
        for (let i = 0; i < 15; i++) {
            const mod = (!test && ((bits >> i) & 1) == 1);
            if (i < 6) {
                this.modules[i][8] = mod;
            } else if (i < 8) {
                this.modules[i + 1][8] = mod;
            } else {
                this.modules[this.moduleCount - 15 + i][8] = mod;
            }
        }
        for (let i = 0; i < 15; i++) {
            const mod = (!test && ((bits >> i) & 1) == 1);
            if (i < 8) {
                this.modules[8][this.moduleCount - i - 1] = mod;
            } else if (i < 9) {
                this.modules[8][15 - i - 1 + 1] = mod;
            } else {
                this.modules[8][15 - i - 1] = mod;
            }
        }
        this.modules[this.moduleCount - 8][8] = (!test);
    }

    mapData(data: number[], maskPattern: number): void {
        let inc = -1;
        let row = this.moduleCount - 1;
        let bitIndex = 7;
        let byteIndex = 0;
        for (let col = this.moduleCount - 1; col > 0; col -= 2) {
            if (col == 6) col--;
            while (true) {
                for (let c = 0; c < 2; c++) {
                    if (this.modules[row][col - c] == null) {
                        let dark = false;
                        if (byteIndex < data.length) {
                            dark = (((data[byteIndex] >>> bitIndex) & 1) == 1);
                        }
                        const mask = QRUtil.getMask(maskPattern, row, col - c);
                        if (mask) dark = !dark;
                        this.modules[row][col - c] = dark;
                        bitIndex--;
                        if (bitIndex == -1) {
                            byteIndex++;
                            bitIndex = 7;
                        }
                    }
                }
                row += inc;
                if (row < 0 || this.moduleCount <= row) {
                    row -= inc;
                    inc = -inc;
                    break;
                }
            }
        }
    }

    static createData(typeNumber: number, errorCorrectLevel: QRErrorCorrectLevel, dataList: QR8bitByte[]): number[] {
        const rsBlocks = QRRSBlock.getRSBlocks(typeNumber, errorCorrectLevel);
        const buffer = new QRBitBuffer();
        for (let i = 0; i < dataList.length; i++) {
            const data = dataList[i];
            buffer.put(data.mode, 4);
            buffer.put(data.getLength(), QRUtil.getLengthInBits(data.mode, typeNumber));
            data.write(buffer);
        }
        let totalDataCount = 0;
        for (let i = 0; i < rsBlocks.length; i++) {
            totalDataCount += rsBlocks[i].dataCount;
        }
        if (buffer.getLengthInBits() > totalDataCount * 8) {
            throw new Error("code length overflow. (" + buffer.getLengthInBits() + ">" + totalDataCount * 8 + ")");
        }
        if (buffer.getLengthInBits() + 4 <= totalDataCount * 8) {
            buffer.put(0, 4);
        }
        while (buffer.getLengthInBits() % 8 != 0) {
            buffer.putBit(false);
        }
        while (true) {
            if (buffer.getLengthInBits() >= totalDataCount * 8) break;
            buffer.put(QRCodeModel.PAD0, 8);
            if (buffer.getLengthInBits() >= totalDataCount * 8) break;
            buffer.put(QRCodeModel.PAD1, 8);
        }
        return QRCodeModel.createBytes(buffer, rsBlocks);
    }

    static createBytes(buffer: QRBitBuffer, rsBlocks: QRRSBlock[]): number[] {
        let offset = 0;
        let maxDcCount = 0;
        let maxEcCount = 0;
        const dcdata: number[][] = new Array(rsBlocks.length);
        const ecdata: number[][] = new Array(rsBlocks.length);
        for (let r = 0; r < rsBlocks.length; r++) {
            const dcCount = rsBlocks[r].dataCount;
            const ecCount = rsBlocks[r].totalCount - dcCount;
            maxDcCount = Math.max(maxDcCount, dcCount);
            maxEcCount = Math.max(maxEcCount, ecCount);
            dcdata[r] = new Array(dcCount);
            for (let i = 0; i < dcdata[r].length; i++) {
                dcdata[r][i] = 0xff & buffer.getBuffer()[i + offset];
            }
            offset += dcCount;
            const rsPoly = QRUtil.getErrorCorrectPolynomial(ecCount);
            const rawPoly = new QRPolynomial(dcdata[r], rsPoly.getLength() - 1);
            const modPoly = rawPoly.mod(rsPoly);
            ecdata[r] = new Array(rsPoly.getLength() - 1);
            for (let i = 0; i < ecdata[r].length; i++) {
                const modIndex = i + modPoly.getLength() - ecdata[r].length;
                ecdata[r][i] = (modIndex >= 0) ? modPoly.get(modIndex) : 0;
            }
        }
        let totalCodeCount = 0;
        for (let i = 0; i < rsBlocks.length; i++) {
            totalCodeCount += rsBlocks[i].totalCount;
        }
        const data: number[] = new Array(totalCodeCount);
        let index = 0;
        for (let i = 0; i < maxDcCount; i++) {
            for (let r = 0; r < rsBlocks.length; r++) {
                if (i < dcdata[r].length) {
                    data[index++] = dcdata[r][i];
                }
            }
        }
        for (let i = 0; i < maxEcCount; i++) {
            for (let r = 0; r < rsBlocks.length; r++) {
                if (i < ecdata[r].length) {
                    data[index++] = ecdata[r][i];
                }
            }
        }
        return data;
    }

    static PAD0 = 0xEC;
    static PAD1 = 0x11;
}

class QRRSBlock {
    totalCount: number;
    dataCount: number;

    constructor(totalCount: number, dataCount: number) {
        this.totalCount = totalCount;
        this.dataCount = dataCount;
    }

    static getRSBlocks(typeNumber: number, errorCorrectLevel: QRErrorCorrectLevel): QRRSBlock[] {
        const rsBlock = QRRSBlock.getRsBlockTable(typeNumber, errorCorrectLevel);
        if (rsBlock == undefined) {
            throw new Error("bad rs block @ typeNumber:" + typeNumber + "/errorCorrectLevel:" + errorCorrectLevel);
        }
        const length = rsBlock.length / 3;
        const list: QRRSBlock[] = [];
        for (let i = 0; i < length; i++) {
            const count = rsBlock[i * 3 + 0];
            const totalCount = rsBlock[i * 3 + 1];
            const dataCount = rsBlock[i * 3 + 2];
            for (let j = 0; j < count; j++) {
                list.push(new QRRSBlock(totalCount, dataCount));
            }
        }
        return list;
    }

    static getRsBlockTable(typeNumber: number, errorCorrectLevel: QRErrorCorrectLevel): number[] | undefined {
        switch (errorCorrectLevel) {
            case QRErrorCorrectLevel.L:
                return RS_BLOCK_TABLE[(typeNumber - 1) * 4 + 0];
            case QRErrorCorrectLevel.M:
                return RS_BLOCK_TABLE[(typeNumber - 1) * 4 + 1];
            case QRErrorCorrectLevel.Q:
                return RS_BLOCK_TABLE[(typeNumber - 1) * 4 + 2];
            case QRErrorCorrectLevel.H:
                return RS_BLOCK_TABLE[(typeNumber - 1) * 4 + 3];
            default:
                return undefined;
        }
    }
}

class QRBitBuffer {
    buffer: number[] = [];
    length = 0;

    getBuffer(): number[] {
        return this.buffer;
    }

    get(index: number): number {
        const bufIndex = Math.floor(index / 8);
        return ((this.buffer[bufIndex] >>> (7 - index % 8)) & 1);
    }

    put(num: number, length: number): void {
        for (let i = 0; i < length; i++) {
            this.putBit(((num >>> (length - i - 1)) & 1) == 1);
        }
    }

    getLengthInBits(): number {
        return this.length;
    }

    putBit(bit: boolean): void {
        const bufIndex = Math.floor(this.length / 8);
        if (this.buffer.length <= bufIndex) {
            this.buffer.push(0);
        }
        if (bit) {
            this.buffer[bufIndex] |= (0x80 >>> (this.length % 8));
        }
        this.length++;
    }
}

const EXP_TABLE: number[] = new Array(256);
const LOG_TABLE: number[] = new Array(256);

for (let i = 0; i < 8; i++) EXP_TABLE[i] = 1 << i;
for (let i = 8; i < 256; i++) EXP_TABLE[i] = EXP_TABLE[i - 4] ^ EXP_TABLE[i - 5] ^ EXP_TABLE[i - 6] ^ EXP_TABLE[i - 8];
for (let i = 0; i < 255; i++) LOG_TABLE[EXP_TABLE[i]] = i;

const QR_PATTERN_POSITION_TABLE = [
    [],
    [6, 18],
    [6, 22],
    [6, 26],
    [6, 30],
    [6, 34],
    [6, 22, 38],
    [6, 24, 42],
    [6, 26, 46],
    [6, 28, 50],
    [6, 30, 54],
    [6, 32, 58],
    [6, 34, 62],
    [6, 26, 46, 66],
    [6, 26, 48, 70],
    [6, 26, 50, 74],
    [6, 30, 54, 78],
    [6, 30, 56, 82],
    [6, 30, 58, 86],
    [6, 34, 62, 90],
    [6, 28, 50, 72, 94],
    [6, 26, 50, 74, 98],
    [6, 30, 54, 78, 102],
    [6, 28, 54, 80, 106],
    [6, 32, 58, 84, 110],
    [6, 30, 58, 86, 114],
    [6, 34, 62, 90, 118],
    [6, 26, 50, 74, 98, 122],
    [6, 30, 54, 78, 102, 126],
    [6, 26, 52, 78, 104, 130],
    [6, 30, 56, 82, 108, 134],
    [6, 34, 60, 86, 112, 138],
    [6, 30, 58, 86, 114, 142],
    [6, 34, 62, 90, 118, 146],
    [6, 30, 54, 78, 102, 126, 150],
    [6, 24, 50, 76, 102, 128, 154],
    [6, 28, 54, 80, 106, 132, 158],
    [6, 32, 58, 84, 110, 136, 162],
    [6, 26, 54, 82, 110, 138, 166],
    [6, 30, 58, 86, 114, 142, 170]
];

const RS_BLOCK_TABLE = [
    [1, 26, 19],
    [1, 26, 16],
    [1, 26, 13],
    [1, 26, 9],
    [1, 44, 34],
    [1, 44, 28],
    [1, 44, 22],
    [1, 44, 16],
    [1, 70, 55],
    [1, 70, 44],
    [2, 35, 17],
    [2, 35, 13],
    [1, 100, 80],
    [2, 50, 32],
    [2, 50, 24],
    [4, 25, 9],
    [1, 134, 108],
    [2, 67, 43],
    [2, 33, 15, 2, 34, 16],
    [2, 33, 11, 2, 34, 12],
    [2, 86, 68],
    [4, 43, 27],
    [4, 43, 19],
    [4, 43, 15],
    [2, 98, 78],
    [4, 49, 31],
    [2, 32, 14, 4, 33, 15],
    [4, 39, 13, 1, 40, 14],
    [2, 121, 97],
    [2, 60, 38, 2, 61, 39],
    [4, 40, 18, 2, 41, 19],
    [4, 40, 14, 2, 41, 15],
    [2, 146, 116],
    [3, 58, 36, 2, 59, 37],
    [4, 36, 16, 4, 37, 17],
    [4, 36, 12, 4, 37, 13],
    [2, 86, 68, 2, 87, 69],
    [4, 69, 43, 1, 70, 44],
    [6, 43, 19, 2, 44, 20],
    [6, 43, 15, 2, 44, 16],
    [4, 101, 81],
    [1, 80, 50, 4, 81, 51],
    [4, 50, 22, 4, 51, 23],
    [3, 36, 12, 8, 37, 13],
    [2, 116, 92, 2, 117, 93],
    [6, 58, 36, 2, 59, 37],
    [4, 46, 20, 6, 47, 21],
    [7, 42, 14, 4, 43, 15],
    [4, 133, 107],
    [8, 59, 37, 1, 60, 38],
    [8, 44, 20, 4, 45, 21],
    [12, 33, 11, 4, 34, 12],
    [3, 145, 115, 1, 146, 116],
    [4, 64, 40, 5, 65, 41],
    [11, 36, 16, 5, 37, 17],
    [11, 36, 12, 5, 37, 13],
    [5, 109, 87, 1, 110, 88],
    [5, 65, 41, 5, 66, 42],
    [5, 54, 24, 7, 55, 25],
    [11, 36, 12],
    [5, 122, 98, 1, 123, 99],
    [7, 73, 45, 3, 74, 46],
    [15, 43, 19, 2, 44, 20],
    [3, 45, 15, 13, 46, 16],
    [1, 135, 107, 5, 136, 108],
    [10, 74, 46, 1, 75, 47],
    [1, 50, 22, 15, 51, 23],
    [2, 42, 14, 17, 43, 15],
    [5, 150, 120, 1, 151, 121],
    [9, 69, 43, 4, 70, 44],
    [17, 50, 22, 1, 51, 23],
    [2, 42, 14, 19, 43, 15],
    [3, 141, 113, 4, 142, 114],
    [3, 70, 44, 11, 71, 45],
    [17, 47, 21, 4, 48, 22],
    [9, 39, 13, 16, 40, 14],
    [3, 135, 107, 5, 136, 108],
    [3, 67, 41, 13, 68, 42],
    [15, 54, 24, 5, 55, 25],
    [15, 43, 15, 10, 44, 16],
    [4, 144, 116, 4, 145, 117],
    [17, 68, 42],
    [17, 50, 22, 6, 51, 23],
    [19, 46, 16, 6, 47, 17],
    [2, 139, 111, 7, 140, 112],
    [17, 74, 46],
    [7, 54, 24, 16, 55, 25],
    [34, 37, 13],
    [4, 151, 121, 5, 152, 122],
    [4, 75, 47, 14, 76, 48],
    [11, 54, 24, 14, 55, 25],
    [16, 45, 15, 14, 46, 16],
    [6, 147, 117, 4, 148, 118],
    [6, 73, 45, 14, 74, 46],
    [11, 54, 24, 16, 55, 25],
    [30, 46, 16, 2, 47, 17],
    [8, 132, 106, 4, 133, 107],
    [8, 75, 47, 13, 76, 48],
    [7, 54, 24, 22, 55, 25],
    [22, 45, 15, 13, 46, 16],
    [10, 142, 114, 2, 143, 115],
    [19, 74, 46, 4, 75, 47],
    [28, 50, 22, 6, 51, 23],
    [33, 46, 16, 4, 47, 17],
    [8, 152, 122, 4, 153, 123],
    [22, 73, 45, 3, 74, 46],
    [8, 53, 23, 26, 54, 24],
    [12, 45, 15, 28, 46, 16],
    [3, 147, 117, 10, 148, 118],
    [3, 73, 45, 23, 74, 46],
    [4, 54, 24, 31, 55, 25],
    [11, 45, 15, 31, 46, 16],
    [7, 146, 116, 7, 147, 117],
    [21, 73, 45, 7, 74, 46],
    [1, 53, 23, 37, 54, 24],
    [19, 45, 15, 26, 46, 16],
    [5, 145, 115, 10, 146, 116],
    [19, 75, 47, 10, 76, 48],
    [15, 54, 24, 25, 55, 25],
    [23, 45, 15, 25, 46, 16],
    [13, 145, 115, 3, 146, 116],
    [2, 74, 46, 29, 75, 47],
    [42, 54, 24, 1, 55, 25],
    [23, 45, 15, 28, 46, 16],
    [17, 145, 115],
    [10, 74, 46, 23, 75, 47],
    [10, 54, 24, 35, 55, 25],
    [19, 45, 15, 35, 46, 16],
    [17, 145, 115, 1, 146, 116],
    [14, 74, 46, 21, 75, 47],
    [29, 54, 24, 19, 55, 25],
    [11, 45, 15, 46, 46, 16],
    [13, 145, 115, 6, 146, 116],
    [14, 74, 46, 23, 75, 47],
    [44, 54, 24, 7, 55, 25],
    [59, 46, 16, 1, 47, 17],
    [12, 151, 121, 7, 152, 122],
    [12, 75, 47, 26, 76, 48],
    [39, 54, 24, 14, 55, 25],
    [22, 45, 15, 41, 46, 16],
    [6, 151, 121, 14, 152, 122],
    [6, 75, 47, 34, 76, 48],
    [46, 54, 24, 10, 55, 25],
    [2, 45, 15, 64, 46, 16],
    [17, 152, 122, 4, 153, 123],
    [29, 74, 46, 14, 75, 47],
    [49, 54, 24, 10, 55, 25],
    [24, 45, 15, 46, 46, 16],
    [4, 152, 122, 18, 153, 123],
    [13, 74, 46, 32, 75, 47],
    [48, 54, 24, 14, 55, 25],
    [42, 45, 15, 32, 46, 16],
    [20, 147, 117, 4, 148, 118],
    [40, 75, 47, 7, 76, 48],
    [43, 54, 24, 22, 55, 25],
    [10, 45, 15, 67, 46, 16],
    [19, 148, 118, 6, 149, 119],
    [18, 75, 47, 31, 76, 48],
    [34, 54, 24, 34, 55, 25],
    [20, 45, 15, 61, 46, 16]
];

function _getUTF8Length(sText: string): number {
    let nLength = 0;
    for (let i = 0; i < sText.length; i++) {
        const nCharCode = sText.charCodeAt(i);
        if (nCharCode < 0x80) {
            nLength++;
        } else if (nCharCode < 0x800) {
            nLength += 2;
        } else if (nCharCode < 0x10000) {
            nLength += 3;
        } else if (nCharCode < 0x200000) {
            nLength += 4;
        }
    }
    return nLength;
}

function _getTypeNumber(sText: string, nCorrectLevel: QRErrorCorrectLevel): number {
    let nLength = _getUTF8Length(sText);
    let nType = 1;
    let nLimit = 0;

    for (let i = 1; i < 41; i++) {
        nLimit = 0;
        switch (nCorrectLevel) {
            case QRErrorCorrectLevel.L:
                nLimit = RS_BLOCK_TABLE[(i - 1) * 4 + 0][0];
                break;
            case QRErrorCorrectLevel.M:
                nLimit = RS_BLOCK_TABLE[(i - 1) * 4 + 1][0];
                break;
            case QRErrorCorrectLevel.Q:
                nLimit = RS_BLOCK_TABLE[(i - 1) * 4 + 2][0];
                break;
            case QRErrorCorrectLevel.H:
                nLimit = RS_BLOCK_TABLE[(i - 1) * 4 + 3][0];
                break;
        }

        if (nLength <= nLimit) {
            break;
        }
        nType = i + 1;
    }

    if (nType > 40) {
        throw new Error("Too long data");
    }

    return nType;
}

export function generateQrCodeMatrix(text: string): (boolean | null)[][] {
    const correctLevel = QRErrorCorrectLevel.M;
    const typeNumber = _getTypeNumber(text, correctLevel);
    const model = new QRCodeModel(typeNumber, correctLevel);
    model.addData(text);
    model.make();
    return model.modules;
}
