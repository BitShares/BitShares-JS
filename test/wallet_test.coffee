{Wallet} = require '../src/wallet/wallet'
{WalletDb} = require '../src/wallet/wallet_db'
{WalletAPI} = require '../src/client/wallet_api'
{TransactionLedger} = require '../src/wallet/transaction_ledger'
{ChainInterface} = require '../src/blockchain/chain_interface'
wallet_object = require './fixtures/wallet.json'
EC = require('../src/common/exceptions').ErrorWithCause
secureRandom = require 'secure-random'

# clone
wallet_object_string = JSON.stringify wallet_object

describe "Wallet API", ->
    
    beforeEach ->
        # create / reset in ram
        wallet_object = JSON.parse wallet_object_string
        @wallet_db = new WalletDb wallet_object, "default"
        @chain_interface = new ChainInterface()
        @wallet = new Wallet @wallet_db, @chain_interface
        @transaction_ledger = new TransactionLedger @wallet_db
        @wallet_api = new WalletAPI(
            @wallet
            @wallet_db
            @transaction_ledger
            @chain_interface
        )
        
    afterEach ->
        # delete from persistent storage if exists
        WalletDb.delete "default"
    
    it "backup_restore_object", (done) ->
        WalletDb.delete "default" # prior run failed
        wallet_db = @wallet_api.backup_restore_object wallet_object, "default"
        unless wallet_db and wallet_db.wallet_name
            EC.throw 'missing wallet_db'
        try
            @wallet_api.backup_restore_object wallet_object, "default"
            EC.throw 'allowed to restore over existing wallet'
        catch error
            unless error.key is 'wallet.exists'
                EC.throw 'expecting error: wallet.exists', error
            WalletDb.delete wallet_db.wallet_name
            done()
    
    it "save", ->
        @wallet_db.save()
        unless WalletDb.open "default"
            EC.throw "Could not open wallet after save"
    
    it "open", (done) ->
        @wallet_db.save()
        try
            @wallet_api.open("WalletNotFound")
            EC.throw 'opened wallet that does not exists'
        catch error
            unless error.key is 'wallet.not_found'
                EC.throw 'Expecting wallet.not_found', error
            try
                @wallet_api.open("default")
                unless @wallet_api.wallet_db.wallet_name is "default"
                    EC.throw "Expecting wallet named default"
                
                WalletDb.delete "default"
                done()
            catch error
                EC.throw 'failed to open existing wallet', error
    
    it "validate_password", (done) ->
        try
            @wallet_api.validate_password("Wrong Password")
            EC.throw "wrong password verified"
        catch error
            unless error.key is 'wallet.invalid_password'
                EC.throw 'Expecting wallet.invalid_password', error
            try
                @wallet_api.validate_password(correct_password = "Password00")
                done()
            catch error
                EC.throw "correct password did not verify", error
        
    it "unlock", (done) ->
        try
            @wallet_api.unlock(2, "Wrong Password")
            EC.throw 'allowed to unlock with wrong password'
        catch error
            unless error.key is 'wallet.invalid_password'
                EC.throw 'Expecting wallet.invalid_password', error
            try
                @wallet_api.unlock(2, "Password00")
                done()
            catch error
                EC.throw 'unable to unlock with the correct password', error
    
    it "lock", ->
        @wallet_api.lock()
        EC.throw "Wallet should be locked" unless @wallet_api.locked()
        EC.throw "Locked wallet should not have an AES object" if @wallet_api.root_aes
        
    it "create password wallet", ->
        WalletDb.delete "default"
        entropy = secureRandom.randomUint8Array(1000)
        Wallet.add_entropy new Buffer entropy
        try
            @wallet_api.create "default", "Password00"
            #console.log @wallet_api.wallet.toJson 4
        finally
            WalletDb.delete "default"
            
    it "store and retrieve settings", ->
        @wallet_api.set_setting "key", "value"
        setting = @wallet_api.get_setting "key"
        throw "Setting key did not match #{value}" unless setting.value is "value"
    
    it "list accounts", ->
        accounts = @wallet_api.list_accounts()
        EC.throw "No accounts" unless accounts or accounts.length > 0
        
    it "transaction history", ->
        history = @wallet_api.account_transaction_history()
        EC.throw 'no history' unless history?.length > 0

    it "create account", ->
        @wallet_api.unlock(2, "Password00")
        public_key = @wallet_api.account_create 'newname', {private:'data'}
        #console.log public_key, JSON.stringify @wallet_db.wallet_object[@wallet_db.wallet_object.length-1],null,4
        EC.throw 'expecting public key' unless public_key
       
    ###
    it "create brain-key wallet", ->
        # exception in wallet.coffee: throw 'Brain keys have not been tested with the native client'
        phrase = "Qtn3E@gU-BrainKey https://www.grc.com/passwords.htm UfN71K&rS&VdqVE" 
        try
            @wallet_api.create "default", "Password00", phrase
        finally
            WalletDb.delete "default"
    ###
    
    
    