CREATE DATABASE IF NOT EXISTS BANKING_ANALYTICS_DB;
CREATE SCHEMA IF NOT EXISTS BANKING_ANALYTICS_DB.BANKING;

USE DATABASE BANKING_ANALYTICS_DB;
USE SCHEMA BANKING;

CREATE OR REPLACE TABLE BANK_TRANSACTIONS (
    TransactionID VARCHAR,
    CustomerID VARCHAR,
    CustomerDOB DATE,
    CustGender VARCHAR,
    CustLocation VARCHAR,
    CustAccountBalance FLOAT,
    TransactionDate DATE,
    TransactionTime TIME,
    TransactionAmount_INR FLOAT,
    CustomerAge FLOAT,
    TransactionHour INTEGER,
    AgeGroup VARCHAR,
    TimeOfDay VARCHAR,
    TransactionMonth INTEGER,
    TransactionMonthName VARCHAR,
    TransactionDay VARCHAR,
    TransactionAmountBand VARCHAR,
    AccountBalanceBand VARCHAR
);