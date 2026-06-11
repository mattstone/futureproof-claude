#!/usr/bin/env python3
"""
Generate FutureProof EPM Tax Discussion PDFs — one per jurisdiction (AU, NZ, UK, US).
Matching the style of the existing EPM analysis reports.
"""

import os
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.lib.enums import TA_LEFT, TA_CENTER, TA_JUSTIFY
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    PageBreak, KeepTogether
)
from reportlab.lib.colors import HexColor

# ============================================================
# COLOUR PALETTE (matching existing EPM reports)
# ============================================================
DARK_NAVY = HexColor('#2C3E50')
TEAL = HexColor('#3498A8')
CORAL = HexColor('#C0392B')
LIGHT_GREY = HexColor('#F5F5F5')
MID_GREY = HexColor('#95A5A6')
WHITE = colors.white
HEADER_BG = HexColor('#2C3E50')
ROW_ALT = HexColor('#F8F9FA')
GREEN = HexColor('#27AE60')
AMBER = HexColor('#F39C12')

PAGE_W, PAGE_H = A4
MARGIN = 20 * mm


# ============================================================
# JURISDICTION-SPECIFIC DATA
# ============================================================
JURISDICTIONS = {
    'AU': {
        'country': 'Australia',
        'currency': 'AUD',
        'currency_symbol': 'A$',
        'regulator': 'Australian Prudential Regulation Authority (APRA)',
        'conduct_regulator': 'Australian Securities and Investments Commission (ASIC)',
        'tax_authority': 'Australian Taxation Office (ATO)',
        'gst_vat_name': 'GST',
        'gst_vat_rate': '10%',
        'income_tax_rates': '0% (≤$18,200), 19% ($18,201–$45,000), 32.5% ($45,001–$120,000), 37% ($120,001–$180,000), 45% (>$180,000) + 2% Medicare Levy',
        'company_tax': '25% (base rate entity) or 30% (otherwise)',
        'capital_gains': 'Included in assessable income at marginal rate. 50% discount for assets held >12 months by individuals. No discount for companies.',
        'withholding_tax': '10% on interest paid to non-residents (may be reduced by DTA). Unfranked dividend WHT 30% (reduced by DTA to 15% for treaty countries).',
        'stamp_duty': 'State-based stamp duty on property transfers. Rates vary by state (e.g., NSW: 1.25%–7%, VIC: 1.4%–6.5%). Some first-home buyer concessions.',
        'reporting': 'Annual tax return (due 31 October for individuals, 28 February for companies). Business Activity Statements (BAS) quarterly for GST. Transfer pricing documentation for related-party transactions.',
        'trust_regime': 'Managed Investment Trust (MIT) regime — fund-level taxation with flow-through treatment. MIT withholding rate 15% for treaty countries on fund payments.',
        'thin_cap': 'Thin capitalisation rules apply: debt-to-equity ratio max 1.5:1 (60% debt). Interest deductions denied on excess debt.',
        'transfer_pricing': 'Arm\'s length principle per OECD guidelines. Country-by-country reporting for large groups (>A$1bn global revenue). Contemporaneous documentation required.',
        'anti_avoidance': 'Part IVA general anti-avoidance rule. Multinational Anti-Avoidance Law (MAAL) for significant global entities. Diverted Profits Tax (DPT) at 40%.',
        'financial_services_licensing': 'Australian Financial Services Licence (AFSL) required for dealing in, or providing advice about, financial products. Responsible lending obligations under National Consumer Credit Protection Act 2009.',
        'mortgage_deductibility': 'Interest on loans for investment purposes is generally deductible. Interest on owner-occupied home mortgages is NOT deductible (unlike US). Negative gearing: investment property losses can offset salary income.',
        'franking': 'Franking (imputation) credit system: company tax paid on profits is passed through as a credit to shareholders on dividends. Fully franked dividends carry a credit equal to the company tax paid. Refundable for individuals/super funds.',
        'superannuation_implications': 'EPM annuity income is NOT super — it is mortgage proceeds. Not subject to super contribution caps. Does not affect Age Pension asset/income tests (as mortgage liability offsets property value). Centrelink treatment: mortgage balance reduces assessable assets.',
        'homeowner_tax_treatment': [
            'EPM annuity payments are structured as mortgage drawdowns, NOT assessable income',
            'No income tax is payable on monthly EPM distributions received',
            'Property remains in homeowner\'s name — no CGT event occurs on establishment',
            'If property is principal place of residence (PPOR), CGT main residence exemption continues to apply',
            'Stamp duty is NOT triggered as no property transfer occurs',
            'Interest component of the mortgage is not deductible (PPOR, non-investment purpose)',
            'Centrelink/Age Pension: mortgage liability offsets property value in asset test',
            'Upon death, property passes to estate per will — standard CGT rules for inherited property apply'
        ],
        'lender_tax_treatment': [
            'Interest income received on EPM mortgages is assessable income under s6-5 ITAA 1997',
            'Establishment and origination fees are assessable income when received',
            'Loan origination costs may be deductible over the life of the loan (s40-880)',
            'Bad debt deductions available under s25-35 for loans written off as bad',
            'Provisioning for expected credit losses (ECL) under AASB 9 — tax deduction only when debt becomes bad',
            'PAYG withholding obligations on employee salaries; BAS reporting quarterly',
            'Must hold Australian Credit Licence (ACL) under NCCP Act',
            'Transfer pricing compliance required for related-party funding arrangements'
        ],
        'wholesale_funder_tax_treatment': [
            'Interest income from lending to the EPM lender is assessable income',
            'If non-resident: 10% interest WHT under ITA s128B (may be reduced by DTA)',
            'Thin capitalisation rules apply to the funding structure — debt-to-equity ratio max 1.5:1',
            'Transfer pricing arm\'s length requirement on inter-company interest rates',
            'Securitisation vehicles: special purpose trust (SPT) tax treatment available',
            'Managed Investment Trust (MIT) withholding rate 15% for treaty-country investors',
            'Cross-border funding: consider BEPS Action 4 (interest deduction limitation) and Action 2 (hybrid mismatches)',
            'GST-free: financial supply of lending is an input-taxed supply (no GST on interest)'
        ],
        'investment_provider_tax_treatment': [
            'Portfolio composition: ~70% S&P 500 ETFs, ~30% fixed income (per EPM investment mandate)',
            'Fund taxed as a trust (MIT) — income flows through to beneficiaries (the EPM structure)',
            'Australian-source dividends: franking credits flow through to fund investors',
            'Foreign-source income (US ETFs): FITO (Foreign Income Tax Offset) available for US withholding tax paid',
            'US ETFs: US-source dividends subject to 15% US WHT (under Australia-US DTA)',
            'Capital gains on disposal of ETF units: 50% CGT discount if held >12 months (trust level)',
            'Interest income from fixed income: assessable at marginal/fund rate',
            'Surplus distribution through payments waterfall follows trust distribution provisions (Div 6)',
            'GST: fund management fees are a financial supply — input tax credits reduced (75% RITC for financial supply acquisitions)'
        ],
        'broker_tax_treatment': [
            'Upfront commission income is assessable in the year received (s6-5 ITAA 1997)',
            'Trail commissions are assessable when received or when an entitlement to receive arises',
            'GST: financial supply — commission on credit products is input-taxed (no GST charged)',
            'ABN required; BAS lodgement if GST-registered (>$75k turnover)',
            'Broker must hold Australian Credit Licence (ACL) or be an authorised credit representative',
            'Professional indemnity insurance costs deductible',
            'Best interests duty under NCCP Act — impacts commission structures',
            'Clawback provisions: if commission is clawed back, adjustment to assessable income in year of clawback'
        ],
    },
    'NZ': {
        'country': 'New Zealand',
        'currency': 'NZD',
        'currency_symbol': 'NZ$',
        'regulator': 'Reserve Bank of New Zealand (RBNZ)',
        'conduct_regulator': 'Financial Markets Authority (FMA)',
        'tax_authority': 'Inland Revenue (IRD)',
        'gst_vat_name': 'GST',
        'gst_vat_rate': '15%',
        'income_tax_rates': '10.5% (≤$14,000), 17.5% ($14,001–$48,000), 30% ($48,001–$70,000), 33% ($70,001–$180,000), 39% (>$180,000)',
        'company_tax': '28%',
        'capital_gains': 'No general capital gains tax. Bright-line test: residential property sold within 10 years (2 years for new builds) is subject to income tax on gains. Interest limitation rules for residential property.',
        'withholding_tax': 'Non-resident withholding tax (NRWT) 15% on interest (10% under some DTAs). Approved Issuer Levy (AIL) 2% alternative to NRWT on interest.',
        'stamp_duty': 'No stamp duty in New Zealand. No transfer taxes on property purchases.',
        'reporting': 'Annual income tax return (7 July for individuals, various for companies). GST returns (1, 2, or 6 monthly). Transfer pricing documentation required for international related-party transactions.',
        'trust_regime': 'Portfolio Investment Entity (PIE) regime: tax at investor\'s prescribed investor rate (PIR) — max 28%. Multi-rate PIE distributes on a per-investor basis.',
        'thin_cap': 'Thin capitalisation: 60% debt-to-assets ratio for inbound investment. Interest deduction denied on excess debt.',
        'transfer_pricing': 'Arm\'s length principle. Country-by-country reporting aligned with OECD BEPS. New Zealand has a DTA network covering major jurisdictions.',
        'anti_avoidance': 'Section BG 1 general anti-avoidance provision. Specific rules for related-party lending, hybrid instruments, and transfer pricing.',
        'financial_services_licensing': 'Financial Markets Conduct Act 2013 — licensing for financial advice providers. Credit Contracts and Consumer Finance Act 2003 (CCCFA) for lending.',
        'mortgage_deductibility': 'Interest limitation rules: from 1 October 2021, interest on residential investment property is no longer deductible (phased denial). Owner-occupied home mortgage interest is NOT deductible. Business/commercial property interest remains deductible.',
        'franking': 'Imputation credit system similar to Australia. Company tax paid generates imputation credits attached to dividends. Credits can be used to reduce shareholder tax liability but are NOT refundable (unlike AU).',
        'superannuation_implications': 'KiwiSaver: EPM annuity income is NOT KiwiSaver. Does not affect KiwiSaver contribution obligations. NZ Superannuation (state pension): mortgage liability is NOT included in asset testing (NZ Super is not asset-tested — it is universal). Accommodation Supplement may be affected.',
        'homeowner_tax_treatment': [
            'EPM annuity payments are mortgage proceeds — NOT assessable income under s CA 1',
            'No income tax payable on monthly EPM distributions received',
            'Property remains in homeowner\'s name — no disposal event for bright-line purposes',
            'No bright-line test triggered (no change of ownership)',
            'No stamp duty or transfer tax (NZ has neither)',
            'Mortgage interest NOT deductible for owner-occupied residential property',
            'NZ Superannuation: universal entitlement — EPM does NOT affect eligibility',
            'Upon death: property passes per will; bright-line period resets for beneficiary'
        ],
        'lender_tax_treatment': [
            'Interest income is assessable under s CC 1 Income Tax Act 2007',
            'Establishment fees assessable as income when derived',
            'Bad debt deductions under s DB 31 when debt written off as bad',
            'IFRS 9 expected credit loss provisioning — tax deduction only on write-off (not on provision)',
            'Resident withholding tax (RWT) obligations on interest paid to NZ residents',
            'Must be registered as a financial service provider (FSPR) and licensed under CCCFA',
            'Transfer pricing compliance for cross-border related-party transactions',
            'GST: exempt supply — lending and interest are exempt financial services'
        ],
        'wholesale_funder_tax_treatment': [
            'Interest income from lending to EPM lender is assessable income',
            'If non-resident: NRWT 15% on interest (or AIL 2% on approved securities)',
            'Thin capitalisation rules: 60% debt-to-assets ratio',
            'Transfer pricing: arm\'s length interest rate required on related-party lending',
            'Securitisation: special purpose vehicle (SPV) treatment under NZ tax law',
            'Cross-border: consider BEPS hybrid mismatch rules (Part FH of ITA 2007)',
            'GST: exempt financial services — no GST on interest',
            'Approved Issuer Levy (AIL) at 2% is a cost-effective alternative to 15% NRWT for qualifying securities'
        ],
        'investment_provider_tax_treatment': [
            'Portfolio: ~70% S&P 500 ETFs, ~30% fixed income',
            'Portfolio Investment Entity (PIE) regime preferred — taxed at investor PIR (max 28%)',
            'Foreign Investment Fund (FIF) rules apply to offshore investments (>$50k threshold)',
            'FIF calculation methods: Fair Dividend Rate (FDR) — 5% of opening market value deemed income',
            'US ETF dividends: 15% US WHT under NZ-US DTA; foreign tax credit available against NZ tax',
            'NZ-source interest income: taxed at PIR or company rate',
            'Capital gains: not generally taxable (no CGT), but FIF rules may apply',
            'Surplus distribution follows trust/PIE rules depending on structure'
        ],
        'broker_tax_treatment': [
            'Commission income is assessable income in the year derived',
            'Trail commissions assessed on receipt or entitlement basis',
            'GST: financial services are exempt — no GST on mortgage-related commissions',
            'Must be registered on Financial Service Providers Register (FSPR)',
            'Full licence required under Financial Markets Conduct Act for financial advice',
            'CCCFA compliance obligations — responsible lending duties',
            'Professional indemnity insurance costs deductible',
            'Clawback: assessable income adjustment in the period of clawback'
        ],
    },
    'UK': {
        'country': 'United Kingdom',
        'currency': 'GBP',
        'currency_symbol': '£',
        'regulator': 'Prudential Regulation Authority (PRA)',
        'conduct_regulator': 'Financial Conduct Authority (FCA)',
        'tax_authority': 'HM Revenue & Customs (HMRC)',
        'gst_vat_name': 'VAT',
        'gst_vat_rate': '20%',
        'income_tax_rates': '0% (£0–£12,570 personal allowance), 20% (£12,571–£50,270), 40% (£50,271–£125,140), 45% (>£125,140). Personal allowance tapers above £100,000.',
        'company_tax': '25% (profits >£250,000), 19% (small profits ≤£50,000), marginal relief between',
        'capital_gains': 'CGT: 10%/20% (basic/higher rate) for non-residential assets. 18%/24% for residential property (from April 2024). Annual exemption £3,000 (2024/25).',
        'withholding_tax': '20% WHT on interest paid to non-residents (reduced by DTA, typically to 0%–15%). No WHT on dividends.',
        'stamp_duty': 'Stamp Duty Land Tax (SDLT): 0% (≤£250,000), 5% (£250,001–£925,000), 10% (£925,001–£1.5m), 12% (>£1.5m). 3% surcharge on additional properties.',
        'reporting': 'Self-Assessment tax return (31 January online deadline). Corporation Tax return (12 months after accounting period end). Making Tax Digital (MTD) for VAT and income tax.',
        'trust_regime': 'Authorised contractual schemes (ACS) or authorised unit trusts (AUT). OEIC/unit trust taxed at 20% on non-dividend income. Exempt unauthorised unit trusts available for pension/charity investors.',
        'thin_cap': 'Corporate Interest Restriction (CIR): net interest deduction limited to 30% of UK tax-EBITDA (or £2m de minimis). Group ratio election available.',
        'transfer_pricing': 'OECD arm\'s length standard. Country-by-country reporting (>€750m global revenue). Transfer pricing documentation required for material transactions.',
        'anti_avoidance': 'General Anti-Abuse Rule (GAAR). Diverted Profits Tax (DPT) 25%. Targeted anti-avoidance rules (TAARs) for specific provisions.',
        'financial_services_licensing': 'FCA authorisation required for regulated activities (lending, investment management, advice). Consumer Duty (from July 2023). Senior Managers & Certification Regime (SM&CR).',
        'mortgage_deductibility': 'Mortgage interest on residential buy-to-let: restricted to basic rate (20%) tax credit since April 2020. Owner-occupied home mortgage interest: NOT deductible. Commercial property interest: fully deductible against rental income.',
        'franking': 'No imputation/franking system. Dividends taxed at dividend rates: 0% (£1,000 allowance 2024/25), 8.75% (basic), 33.75% (higher), 39.35% (additional rate).',
        'superannuation_implications': 'EPM annuity income is NOT pension income. Does not count toward annual allowance (£60,000) or lifetime allowance. State Pension: not affected by EPM. Pension credit (means-tested): EPM mortgage liability may reduce capital for means-testing purposes.',
        'homeowner_tax_treatment': [
            'EPM annuity payments are mortgage drawdowns — NOT taxable income',
            'No income tax, NICs, or PAYE obligations on EPM distributions',
            'Property remains in homeowner\'s name — no disposal for CGT purposes',
            'Principal Private Residence Relief (PPR) continues to apply — no CGT on main home',
            'SDLT NOT triggered (no property transfer occurs)',
            'Mortgage interest NOT deductible (owner-occupied residential property)',
            'Inheritance Tax (IHT): property value included in estate, but mortgage liability is a deductible debt',
            'Council Tax: no change — homeowner remains liable occupier',
            'State Pension/Pension Credit: EPM capital may affect means-tested benefits'
        ],
        'lender_tax_treatment': [
            'Interest income is trading income subject to Corporation Tax (25%)',
            'Origination fees and arrangement fees are assessable income',
            'Bad debt relief under Corporation Tax Act 2009 Part 5 (loan relationships)',
            'Loan relationship rules: interest and related costs follow accounting treatment',
            'IFRS 9 ECL provisioning: tax deductions generally follow accounts (with adjustments)',
            'Corporate Interest Restriction (CIR): 30% of EBITDA cap on net interest deductions',
            'FCA-authorised: subject to Consumer Duty and responsible lending requirements',
            'VAT: financial services are exempt supplies — no VAT on interest (partial exemption for input VAT)'
        ],
        'wholesale_funder_tax_treatment': [
            'Interest income is assessable under loan relationship rules',
            'If non-UK resident: 20% WHT on interest (reduced under DTA — often 0% for EU/treaty countries)',
            'Corporate Interest Restriction: 30% of UK tax-EBITDA or £2m de minimis',
            'Transfer pricing: arm\'s length requirement on inter-company interest rates',
            'Securitisation: Taxation of Securitisation Companies Regulations 2006 regime available',
            'Hybrid mismatch rules (TIOPA 2010 Part 6A): anti-avoidance on cross-border structures',
            'VAT: exempt financial supply — no VAT on interest',
            'BEPS Pillar 2 (global minimum tax 15%): may apply to large multinational groups'
        ],
        'investment_provider_tax_treatment': [
            'Portfolio: ~70% S&P 500 ETFs, ~30% fixed income',
            'Authorised fund structure: OEIC or AUT taxed at 20% on non-dividend income, exempt on UK dividends',
            'Offshore fund (reporting fund status): gains taxed as capital gains for UK investors',
            'US ETF dividends: 15% US WHT under UK-US DTA; credit against UK tax',
            'Interest income: 20% at fund level (OEIC/AUT)',
            'Capital gains within authorised fund: generally exempt from CGT at fund level',
            'Equalisation payments on unit transactions ensure fair tax treatment',
            'Surplus distribution follows fund prospectus rules and payments waterfall'
        ],
        'broker_tax_treatment': [
            'Commission income is trading income subject to income tax or Corporation Tax',
            'Trail commissions: assessed on an arising basis per GAAP',
            'VAT: exempt financial intermediation — no VAT on mortgage brokerage commissions',
            'FCA authorised and subject to Consumer Duty',
            'Professional indemnity insurance costs deductible',
            'Firms subject to SM&CR individual accountability rules',
            'Clawback provisions: adjustment to trading income in the period of clawback',
            'Money laundering regulations: customer due diligence and reporting obligations'
        ],
    },
    'US': {
        'country': 'United States',
        'currency': 'USD',
        'currency_symbol': '$',
        'regulator': 'Consumer Financial Protection Bureau (CFPB)',
        'conduct_regulator': 'State banking/lending regulators (varies by state)',
        'tax_authority': 'Internal Revenue Service (IRS)',
        'gst_vat_name': 'Sales Tax',
        'gst_vat_rate': 'No federal sales tax; state varies 0%–10.25%',
        'income_tax_rates': 'Federal: 10% (≤$11,600), 12% ($11,601–$47,150), 22% ($47,151–$100,525), 24% ($100,526–$191,950), 32% ($191,951–$243,725), 35% ($243,726–$609,350), 37% (>$609,350). Plus state income tax (0%–13.3%).',
        'company_tax': '21% federal. State corporate tax 0%–11.5% (varies by state). Combined effective rate typically 25%–30%.',
        'capital_gains': 'Long-term (>1 year): 0%/15%/20% based on income. Net Investment Income Tax (NIIT) 3.8% surcharge on higher earners. Short-term: taxed as ordinary income.',
        'withholding_tax': '30% WHT on FDAP income (interest, dividends) paid to non-US persons (reduced by DTA to 0%–15%). FATCA 30% WHT on non-compliant foreign financial institutions.',
        'stamp_duty': 'No federal stamp duty. State/county transfer taxes vary (e.g., NY: 0.4%–1.4%, CA: $1.10 per $1,000). Recording fees also apply.',
        'reporting': 'Individual: Form 1040 (15 April). Corporate: Form 1120 (15 April or 15 October extended). 1098 (mortgage interest paid). 1099-INT (interest income). FBAR and FATCA reporting for foreign financial accounts.',
        'trust_regime': 'Regulated Investment Company (RIC) under IRC Subchapter M — pass-through taxation if 90% of income distributed. Real Estate Mortgage Investment Conduit (REMIC) for mortgage-backed securities.',
        'thin_cap': 'Section 163(j) Business Interest Limitation: net business interest deduction limited to 30% of adjusted taxable income. Excess carried forward indefinitely.',
        'transfer_pricing': 'IRC Section 482 — arm\'s length standard. Country-by-country reporting (Form 8975 for >$850m revenue). Advance Pricing Agreements (APAs) available.',
        'anti_avoidance': 'Economic substance doctrine (IRC §7701(o)). BEAT (Base Erosion and Anti-Abuse Tax) for large taxpayers. GILTI (Global Intangible Low-Taxed Income) for CFC owners.',
        'financial_services_licensing': 'State-by-state mortgage licensing (NMLS). SAFE Act registration for mortgage loan originators. SEC/FINRA for investment management. Dodd-Frank Wall Street Reform Act requirements.',
        'mortgage_deductibility': 'Mortgage interest on primary residence: deductible up to $750,000 of mortgage debt (itemized deduction on Schedule A). Home equity loan interest: deductible only if proceeds used to buy, build, or improve the home. Investment property: interest fully deductible against rental income.',
        'franking': 'No imputation/franking system. Qualified dividends taxed at LTCG rates (0%/15%/20%). Non-qualified dividends taxed as ordinary income.',
        'superannuation_implications': 'EPM annuity income is NOT retirement plan income. Does not affect IRA/401(k) contribution limits or RMDs. Social Security: EPM proceeds are not "earned income" and do not affect benefits. Medicare: EPM proceeds may affect IRMAA (Income-Related Monthly Adjustment Amount) if counted as income — but mortgage drawdowns are generally NOT counted.',
        'homeowner_tax_treatment': [
            'EPM annuity payments are mortgage proceeds — NOT gross income under IRC §61',
            'No federal income tax on EPM distributions (loan proceeds are not income)',
            'Property remains in homeowner\'s name — no sale or exchange for CGT purposes',
            'IRC §121 exclusion ($250k/$500k) continues to apply to principal residence',
            'Mortgage interest may be deductible on Schedule A (itemized) up to $750,000 limit under TCJA',
            'Property taxes remain deductible (subject to $10,000 SALT cap)',
            'No transfer tax triggered (no property transfer occurs)',
            'Estate tax: property included in gross estate (IRC §2031), but mortgage is deductible liability (IRC §2053)',
            'Social Security: EPM proceeds are not "wages" and do not affect SS benefits or earnings test'
        ],
        'lender_tax_treatment': [
            'Interest income is ordinary income under IRC §61(a)(4)',
            'Origination fees and points: income recognition per IRC §451 and OID rules (IRC §1272)',
            'Bad debt deduction under IRC §166 (specific charge-off method for banks)',
            'Reserve for loan losses: IRC §585 (small banks) or §586 (mutual savings banks)',
            'CECL (Current Expected Credit Losses) under ASC 326 — IRS Rev. Proc. 2019-35 transition',
            'Section 163(j): net business interest deduction limited to 30% of ATI',
            'State-by-state mortgage licensing under SAFE Act (NMLS registration)',
            'Form 1098 reporting: must report mortgage interest received from borrowers'
        ],
        'wholesale_funder_tax_treatment': [
            'Interest income is ordinary income (or effectively connected income for US business)',
            'If non-US person: 30% WHT on interest (reduced under DTA — often 0%–15%)',
            'FATCA: 30% WHT on payments to non-compliant foreign financial institutions',
            'Section 163(j): 30% of ATI cap on net interest deductions',
            'Transfer pricing: IRC §482 arm\'s length requirement',
            'REMIC structure available for mortgage-backed securitisation (IRC §860A-G)',
            'BEAT: Base Erosion and Anti-Abuse Tax (10% minimum on large taxpayers with base-eroding payments)',
            'GILTI: CFC shareholders must include GILTI in income (IRC §951A)'
        ],
        'investment_provider_tax_treatment': [
            'Portfolio: ~70% S&P 500 ETFs, ~30% fixed income',
            'Regulated Investment Company (RIC) under Subchapter M: pass-through taxation if 90% of income distributed',
            'Qualified dividend income from US equities: 0%/15%/20% rates at investor level',
            'Interest income from fixed income: taxed as ordinary income to investors',
            'Capital gain distributions: long-term rates if fund held securities >1 year',
            'ETF structure: creation/redemption mechanism minimises capital gains distributions',
            'NIIT: 3.8% surtax on net investment income for individuals earning >$200k/$250k',
            'Form 1099-DIV reporting to investors on dividends and capital gains distributions'
        ],
        'broker_tax_treatment': [
            'Commission income is ordinary income (self-employment or W-2)',
            'Self-employment tax: 15.3% (12.4% Social Security + 2.9% Medicare) on SE income',
            'Trail commissions: recognised as income when received or constructively received',
            'NMLS registration and state-specific mortgage broker licensing required',
            'SAFE Act compliance: mortgage loan originator registration',
            'Dodd-Frank: compliance with ability-to-repay (ATR) and qualified mortgage (QM) rules',
            'Professional liability insurance costs deductible (Schedule C or as business expense)',
            'Clawback: adjustment to income in the period commission is returned'
        ],
    },
}


# ============================================================
# STYLES
# ============================================================
def get_styles():
    styles = getSampleStyleSheet()

    styles.add(ParagraphStyle(
        'CoverTitle', fontName='Helvetica-Bold', fontSize=28,
        textColor=WHITE, leading=34, alignment=TA_LEFT
    ))
    styles.add(ParagraphStyle(
        'CoverSubtitle', fontName='Helvetica', fontSize=14,
        textColor=HexColor('#BDC3C7'), leading=20, alignment=TA_LEFT
    ))
    styles.add(ParagraphStyle(
        'CoverDate', fontName='Helvetica', fontSize=11,
        textColor=HexColor('#95A5A6'), leading=14, alignment=TA_LEFT
    ))
    styles.add(ParagraphStyle(
        'SectionTitle', fontName='Helvetica-Bold', fontSize=16,
        textColor=DARK_NAVY, leading=22, spaceBefore=24, spaceAfter=10
    ))
    styles.add(ParagraphStyle(
        'SubSectionTitle', fontName='Helvetica-Bold', fontSize=12,
        textColor=TEAL, leading=16, spaceBefore=16, spaceAfter=6
    ))
    styles.add(ParagraphStyle(
        'BodyText2', fontName='Helvetica', fontSize=9.5,
        textColor=HexColor('#2C3E50'), leading=14, alignment=TA_JUSTIFY,
        spaceBefore=3, spaceAfter=6
    ))
    styles.add(ParagraphStyle(
        'BulletItem', fontName='Helvetica', fontSize=9.5,
        textColor=HexColor('#2C3E50'), leading=13, leftIndent=20,
        bulletIndent=8, spaceBefore=2, spaceAfter=2
    ))
    styles.add(ParagraphStyle(
        'DisclaimerText', fontName='Helvetica', fontSize=8,
        textColor=MID_GREY, leading=11, alignment=TA_JUSTIFY,
        spaceBefore=6, spaceAfter=4
    ))
    styles.add(ParagraphStyle(
        'TableHeader', fontName='Helvetica-Bold', fontSize=9,
        textColor=WHITE, alignment=TA_LEFT
    ))
    styles.add(ParagraphStyle(
        'TableCell', fontName='Helvetica', fontSize=9,
        textColor=HexColor('#2C3E50'), leading=12, alignment=TA_LEFT
    ))
    styles.add(ParagraphStyle(
        'FooterText', fontName='Helvetica', fontSize=7,
        textColor=MID_GREY, alignment=TA_CENTER
    ))
    return styles


# ============================================================
# HELPER FUNCTIONS
# ============================================================
def make_cover_page(styles, data):
    """Generate the cover page matching existing report style."""
    elements = []

    # Navy background block
    cover_data = [['']]
    cover_table = Table(cover_data, colWidths=[PAGE_W - 2 * MARGIN], rowHeights=[PAGE_H * 0.45])
    cover_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), DARK_NAVY),
        ('VALIGN', (0, 0), (-1, -1), 'BOTTOM'),
        ('LEFTPADDING', (0, 0), (-1, -1), 30),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 30),
    ]))
    elements.append(cover_table)
    elements.append(Spacer(1, -PAGE_H * 0.45 + 50))

    # Title content overlaid on navy block
    title_data = [
        [Paragraph('FUTUREPROOF FINANCIAL', styles['CoverDate'])],
        [Spacer(1, 8)],
        [Paragraph(f'Tax Discussion', styles['CoverTitle'])],
        [Spacer(1, 4)],
        [Paragraph(f'{data["country"]} — Equity Preservation Mortgage', styles['CoverSubtitle'])],
        [Spacer(1, 12)],
        [Paragraph('March 2025', styles['CoverDate'])],
        [Spacer(1, 4)],
        [Paragraph('Stakeholder Tax Treatment &amp; Regulatory Framework', styles['CoverDate'])],
    ]
    title_table = Table(title_data, colWidths=[PAGE_W - 2 * MARGIN - 60])
    title_table.setStyle(TableStyle([
        ('LEFTPADDING', (0, 0), (-1, -1), 30),
        ('RIGHTPADDING', (0, 0), (-1, -1), 30),
        ('TOPPADDING', (0, 0), (-1, -1), 0),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
    ]))
    elements.append(title_table)

    elements.append(PageBreak())
    return elements


def make_key_value_table(data_rows, styles, col_widths=None):
    """Create a styled key-value table."""
    if col_widths is None:
        col_widths = [55 * mm, PAGE_W - 2 * MARGIN - 55 * mm]

    table_data = []
    for key, value in data_rows:
        table_data.append([
            Paragraph(f'<b>{key}</b>', styles['TableCell']),
            Paragraph(str(value), styles['TableCell'])
        ])

    t = Table(table_data, colWidths=col_widths)
    style_cmds = [
        ('GRID', (0, 0), (-1, -1), 0.5, HexColor('#E0E0E0')),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('TOPPADDING', (0, 0), (-1, -1), 6),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('LEFTPADDING', (0, 0), (-1, -1), 8),
        ('RIGHTPADDING', (0, 0), (-1, -1), 8),
    ]
    for i in range(len(table_data)):
        if i % 2 == 0:
            style_cmds.append(('BACKGROUND', (0, i), (-1, i), LIGHT_GREY))
        style_cmds.append(('BACKGROUND', (0, i), (0, i),
                          LIGHT_GREY if i % 2 == 0 else WHITE))

    t.setStyle(TableStyle(style_cmds))
    return t


def make_bullet_list(items, styles):
    """Create a bullet list of paragraphs."""
    elements = []
    for item in items:
        elements.append(Paragraph(f'• {item}', styles['BulletItem']))
    return elements


def make_stakeholder_section(title, items, intro_text, styles):
    """Create a stakeholder section with intro and bullet points."""
    elements = []
    elements.append(Paragraph(title, styles['SubSectionTitle']))
    elements.append(Paragraph(intro_text, styles['BodyText2']))
    elements.extend(make_bullet_list(items, styles))
    elements.append(Spacer(1, 8))
    return elements


# ============================================================
# PDF GENERATION
# ============================================================
def generate_pdf(jurisdiction_code):
    data = JURISDICTIONS[jurisdiction_code]
    styles = get_styles()

    filename = f'FutureProof_EPM_Tax_Discussion_{jurisdiction_code}_Mar2025.pdf'
    filepath = os.path.join(os.path.dirname(os.path.abspath(__file__)), filename)

    doc = SimpleDocTemplate(
        filepath, pagesize=A4,
        leftMargin=MARGIN, rightMargin=MARGIN,
        topMargin=15 * mm, bottomMargin=15 * mm
    )

    elements = []

    # --- COVER PAGE ---
    elements.extend(make_cover_page(styles, data))

    # --- TABLE OF CONTENTS ---
    elements.append(Paragraph('Contents', styles['SectionTitle']))
    toc_items = [
        '1. Executive Summary',
        '2. Regulatory Framework',
        '3. Tax Environment Overview',
        '4. Homeowner Tax Treatment',
        '5. Lender Tax Treatment',
        '6. Wholesale Funder Tax Treatment',
        '7. Investment Provider Tax Treatment',
        '8. Broker / Referral Partner Tax Treatment',
        '9. Cross-Border Considerations',
        '10. Anti-Avoidance & Compliance',
        '11. Disclaimer',
    ]
    for item in toc_items:
        elements.append(Paragraph(item, styles['BodyText2']))
    elements.append(PageBreak())

    # --- 1. EXECUTIVE SUMMARY ---
    elements.append(Paragraph('1. Executive Summary', styles['SectionTitle']))
    elements.append(Paragraph(
        f'This document provides a comprehensive discussion of the tax treatment of the '
        f'Equity Preservation Mortgage (EPM) product across all key stakeholders in '
        f'<b>{data["country"]}</b>. The EPM is a structured mortgage product that provides '
        f'homeowners with a guaranteed monthly income stream funded by a combination of mortgage '
        f'drawdowns and a structured investment portfolio (approximately 70% S&amp;P 500 ETFs, '
        f'30% fixed income).', styles['BodyText2']))
    elements.append(Spacer(1, 6))
    elements.append(Paragraph(
        f'The core tax principle underpinning the EPM is that <b>mortgage drawdowns are not income</b>. '
        f'The homeowner receives monthly payments that are structured as loan proceeds, not assessable '
        f'income. This is a well-established principle in {data["country"]} tax law. The investment '
        f'portfolio is managed separately, with returns flowing through the payments waterfall to service '
        f'the mortgage and protect homeowner equity.', styles['BodyText2']))
    elements.append(Spacer(1, 6))
    elements.append(Paragraph(
        f'This report covers the tax position of five stakeholder groups: (1) the Homeowner, '
        f'(2) the Lender, (3) the Wholesale Funder, (4) the Investment Provider, and (5) the '
        f'Broker / Referral Partner. For each stakeholder, we discuss the relevant tax treatment, '
        f'reporting obligations, regulatory requirements, and key considerations.', styles['BodyText2']))
    elements.append(Spacer(1, 6))

    # Key facts summary table
    elements.append(Paragraph('<b>Key Facts</b>', styles['SubSectionTitle']))
    key_facts = [
        ('Jurisdiction', data['country']),
        ('Currency', f'{data["currency"]} ({data["currency_symbol"]})'),
        ('Primary Regulator', data['regulator']),
        ('Conduct Regulator', data['conduct_regulator']),
        ('Tax Authority', data['tax_authority']),
        ('Company Tax Rate', data['company_tax']),
        (data['gst_vat_name'], data['gst_vat_rate']),
    ]
    elements.append(make_key_value_table(key_facts, styles))
    elements.append(PageBreak())

    # --- 2. REGULATORY FRAMEWORK ---
    elements.append(Paragraph('2. Regulatory Framework', styles['SectionTitle']))
    elements.append(Paragraph(
        f'The EPM operates within the regulatory framework of {data["country"]}. '
        f'Prudential supervision is provided by <b>{data["regulator"]}</b>, while conduct '
        f'regulation falls under <b>{data["conduct_regulator"]}</b>. The tax administration is '
        f'overseen by <b>{data["tax_authority"]}</b>.', styles['BodyText2']))
    elements.append(Spacer(1, 6))

    reg_rows = [
        ('Prudential Regulator', data['regulator']),
        ('Conduct Regulator', data['conduct_regulator']),
        ('Tax Authority', data['tax_authority']),
        ('Financial Services Licensing', data['financial_services_licensing']),
    ]
    elements.append(make_key_value_table(reg_rows, styles))
    elements.append(Spacer(1, 12))

    # --- 3. TAX ENVIRONMENT OVERVIEW ---
    elements.append(Paragraph('3. Tax Environment Overview', styles['SectionTitle']))
    elements.append(Paragraph(
        f'This section provides an overview of the {data["country"]} tax environment relevant to '
        f'the EPM product structure and its stakeholders.', styles['BodyText2']))

    tax_rows = [
        ('Personal Income Tax', data['income_tax_rates']),
        ('Company Tax', data['company_tax']),
        ('Capital Gains Tax', data['capital_gains']),
        (data['gst_vat_name'], data['gst_vat_rate']),
        ('Withholding Tax', data['withholding_tax']),
        ('Stamp Duty / Transfer Tax', data['stamp_duty']),
        ('Mortgage Interest Deductibility', data['mortgage_deductibility']),
        ('Imputation / Franking', data['franking']),
        ('Reporting Obligations', data['reporting']),
    ]
    elements.append(make_key_value_table(tax_rows, styles))
    elements.append(Spacer(1, 6))

    elements.append(Paragraph('<b>Structural Tax Provisions</b>', styles['SubSectionTitle']))
    struct_rows = [
        ('Fund / Trust Regime', data['trust_regime']),
        ('Thin Capitalisation', data['thin_cap']),
        ('Transfer Pricing', data['transfer_pricing']),
        ('Anti-Avoidance', data['anti_avoidance']),
    ]
    elements.append(make_key_value_table(struct_rows, styles))

    if data.get('superannuation_implications'):
        elements.append(Spacer(1, 6))
        elements.append(Paragraph('<b>Retirement / Pension System Implications</b>', styles['SubSectionTitle']))
        elements.append(Paragraph(data['superannuation_implications'], styles['BodyText2']))

    elements.append(PageBreak())

    # --- 4–8. STAKEHOLDER SECTIONS ---
    stakeholders = [
        ('4. Homeowner Tax Treatment', 'homeowner_tax_treatment',
         f'The homeowner is the primary beneficiary of the EPM structure. They receive guaranteed '
         f'monthly income while retaining full ownership of their property. The fundamental tax '
         f'principle is that mortgage drawdowns are NOT assessable income in {data["country"]}.'),
        ('5. Lender Tax Treatment', 'lender_tax_treatment',
         f'The lender originates and manages the EPM mortgage. Interest income on the mortgage is the '
         f'primary revenue stream. The lender must comply with {data["country"]} financial services '
         f'licensing requirements and tax reporting obligations.'),
        ('6. Wholesale Funder Tax Treatment', 'wholesale_funder_tax_treatment',
         f'Wholesale funders provide the capital that backs the EPM lending programme. They earn returns '
         f'through the funding margin (the spread between their cost of funds and the rate charged to the '
         f'lender). Cross-border tax considerations are particularly relevant for this stakeholder group.'),
        ('7. Investment Provider Tax Treatment', 'investment_provider_tax_treatment',
         f'The investment provider manages the structured investment portfolio that underpins the EPM. '
         f'The portfolio targets approximately 70% allocation to S&amp;P 500 ETFs and 30% to fixed income '
         f'instruments. Returns from this portfolio flow through the payments waterfall to service mortgage '
         f'interest and protect homeowner equity.'),
        ('8. Broker / Referral Partner Tax Treatment', 'broker_tax_treatment',
         f'Brokers and referral partners earn commission income for originating EPM mortgages. They must '
         f'be appropriately licensed and comply with {data["country"]} regulatory requirements for '
         f'mortgage advice and intermediation.'),
    ]

    for title, key, intro in stakeholders:
        elements.extend(make_stakeholder_section(title, data[key], intro, styles))
        if title.startswith('4.') or title.startswith('6.'):
            elements.append(PageBreak())

    elements.append(PageBreak())

    # --- 9. CROSS-BORDER CONSIDERATIONS ---
    elements.append(Paragraph('9. Cross-Border Considerations', styles['SectionTitle']))
    elements.append(Paragraph(
        f'The EPM structure may involve cross-border elements, particularly where wholesale funding '
        f'or investment management is provided by entities outside {data["country"]}. Key cross-border '
        f'tax considerations include:', styles['BodyText2']))
    cross_border = [
        f'Withholding tax on interest payments to non-resident wholesale funders: {data["withholding_tax"]}',
        'Double Tax Agreement (DTA) network — treaty relief may reduce or eliminate WHT',
        'Transfer pricing documentation requirements for related-party cross-border transactions',
        f'Thin capitalisation rules limiting interest deductions: {data["thin_cap"]}',
        'Permanent establishment (PE) risk — structuring to avoid inadvertent PE creation',
        'BEPS (Base Erosion and Profit Shifting) compliance — CbCR, transfer pricing, anti-hybrid rules',
        'Controlled Foreign Corporation (CFC) rules — may apply to offshore subsidiaries',
        'Foreign tax credit / offset mechanisms to prevent double taxation',
    ]
    elements.extend(make_bullet_list(cross_border, styles))
    elements.append(Spacer(1, 12))

    # --- 10. ANTI-AVOIDANCE & COMPLIANCE ---
    elements.append(Paragraph('10. Anti-Avoidance &amp; Compliance', styles['SectionTitle']))
    elements.append(Paragraph(
        f'The EPM structure is designed to operate within the ordinary commercial framework of '
        f'{data["country"]} tax law. It does not rely on any aggressive tax planning, artificial '
        f'arrangements, or tax avoidance strategies. The structure is transparent, documented, and '
        f'commercially motivated.', styles['BodyText2']))
    elements.append(Spacer(1, 6))
    elements.append(Paragraph(
        f'Nevertheless, all participants should be aware of the anti-avoidance framework:', styles['BodyText2']))
    anti_av = [
        f'General anti-avoidance rule: {data["anti_avoidance"]}',
        f'Transfer pricing: {data["transfer_pricing"]}',
        'Substance requirements — all entities must have genuine economic substance in their jurisdiction',
        'Commercial rationale — all arrangements must have a bona fide commercial purpose beyond tax',
        f'Reporting: {data["reporting"]}',
        'Penalties: significant penalties apply for non-compliance, including promoter penalties for tax schemes',
    ]
    elements.extend(make_bullet_list(anti_av, styles))
    elements.append(PageBreak())

    # --- 11. DISCLAIMER ---
    elements.append(Paragraph('11. Disclaimer', styles['SectionTitle']))
    elements.append(Paragraph(
        'This document has been prepared by Futureproof Financial Group Limited for general '
        'information and discussion purposes only. It does not constitute tax advice, legal advice, '
        'financial advice, or any other form of professional advice.', styles['DisclaimerText']))
    elements.append(Paragraph(
        'Tax treatment depends on the individual circumstances of each stakeholder and may be '
        'subject to change in future. Tax law is complex and subject to interpretation by courts '
        'and tax authorities. The information in this document reflects the law as understood at the '
        'date of publication (March 2025) and may not reflect subsequent changes.', styles['DisclaimerText']))
    elements.append(Paragraph(
        'All stakeholders are strongly advised to seek independent professional tax advice specific '
        'to their individual circumstances before making any decisions based on the information '
        'contained in this document.', styles['DisclaimerText']))
    elements.append(Paragraph(
        'Futureproof Financial Group Limited, its directors, officers, employees, and agents accept '
        'no liability whatsoever for any loss, damage, or expense arising from or in connection with '
        'any reliance placed on the information in this document.', styles['DisclaimerText']))
    elements.append(Spacer(1, 24))
    elements.append(Paragraph(
        '© 2025 Futureproof Financial Group Limited. All Rights Reserved.', styles['DisclaimerText']))
    elements.append(Paragraph(
        '"Equity Preservation Mortgage" is a registered trademark of Futureproof Financial Group Limited.',
        styles['DisclaimerText']))

    # --- BUILD ---
    def add_footer(canvas, doc):
        canvas.saveState()
        canvas.setFont('Helvetica', 7)
        canvas.setFillColor(MID_GREY)
        canvas.drawString(MARGIN, 10 * mm,
                         f'FutureProof EPM — Tax Discussion ({data["country"]}) — March 2025')
        canvas.drawRightString(PAGE_W - MARGIN, 10 * mm, f'Page {doc.page}')
        # Top line
        canvas.setStrokeColor(HexColor('#E0E0E0'))
        canvas.setLineWidth(0.5)
        canvas.line(MARGIN, PAGE_H - 12 * mm, PAGE_W - MARGIN, PAGE_H - 12 * mm)
        canvas.restoreState()

    doc.build(elements, onFirstPage=add_footer, onLaterPages=add_footer)
    print(f'  ✓ Generated: {filename}')
    return filepath


# ============================================================
# MAIN
# ============================================================
if __name__ == '__main__':
    print('Generating FutureProof EPM Tax Discussion PDFs...\n')
    for code in ['AU', 'NZ', 'UK', 'US']:
        generate_pdf(code)
    print(f'\n✅ All 4 Tax Discussion PDFs generated successfully.')
