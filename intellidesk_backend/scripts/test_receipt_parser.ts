import fs from 'fs';
import { extractInvoiceTotal, extractTextFromPdf, parseReceiptMedia } from '../src/services/receiptParser.js';

async function runTest() {
  console.log('--- Test 1: Synthetic OCR text ---');
  const sampleOcrText = `
AURORA CARE GENERAL HOSPITAL
ITEMIZED PATIENT BILL
CHARGES
CONS-101 Initial physician consultation 1 INR 1,200.00 INR 1,200.00
VITAL-205 Vital signs and nursing assessment 1 INR 250.00 INR 250.00
LAB-311 Complete blood count - synthetic panel 1 INR 680.00 INR 680.00
Subtotal INR 4,320.00
Synthetic package discount - INR 220.00
Taxable amount INR 4,100.00
Service tax / levy (5%) INR 205.00
TOTAL AMOUNT DUE INR 4,305.00
PAYMENT / TEST FIELDS
Mode: Sample UPI / Card
Amount Collected: INR 0.00
Balance: INR 4,305.00
`;

  const result1 = extractInvoiceTotal(sampleOcrText);
  console.log('Result 1:', result1);
  if (result1.amount === 4305 && result1.currency === 'INR') {
    console.log('✅ Test 1 Passed!');
  } else {
    console.error('❌ Test 1 Failed!', result1);
  }

  console.log('\n--- Test 2: Actual PDF file if exists ---');
  const pdfPath = 'C:\\Users\\mohan\\Downloads\\fake_hospital_report_test.pdf';
  if (fs.existsSync(pdfPath)) {
    const pdfBuf = fs.readFileSync(pdfPath);
    const pdfText = await extractTextFromPdf(pdfBuf);
    console.log('Extracted PDF Text Length:', pdfText.length);
    const pdfResult = extractInvoiceTotal(pdfText);
    console.log('PDF Result:', pdfResult);
    if (pdfResult.amount === 4305 && pdfResult.currency === 'INR') {
      console.log('✅ Test 2 Passed on real PDF!');
    } else {
      console.error('❌ Test 2 Failed on real PDF!', pdfResult);
    }
  } else {
    console.log('Note: PDF path not found on disk, skipping file test.');
  }
}

runTest();
