module bookswap::book_exchange {
    use std::signer;
    use std::string::{Self, String};
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_std::table::{Self, Table};
    
    // Module owner address
    const MODULE_OWNER: address = @bookswap;

    // Error codes
    const E_BOOK_NOT_FOUND: u64 = 1;
    const E_INSUFFICIENT_PAYMENT: u64 = 2;
    const E_NOT_OWNER: u64 = 3;
    const E_BOOK_NOT_AVAILABLE: u64 = 4;

    // Book structure
    struct Book has store, copy, drop {
        title: String,
        author: String,
        owner: address,
        price: u64,
        available: bool,
    }

    // Global storage for the book exchange
    struct BookExchange has key {
        books: Table<u64, Book>,
        next_book_id: u64,
    }

    // Initialize the book exchange (called once during module publish)
    fun init_module(account: &signer) {
        move_to(account, BookExchange {
            books: table::new(),
            next_book_id: 1,
        });
    }

    // Function 1: List a book for exchange
    public entry fun list_book(
        account: &signer,
        title: String,
        author: String,
        price: u64
    ) acquires BookExchange {
        let owner_addr = signer::address_of(account);
        let exchange = borrow_global_mut<BookExchange>(MODULE_OWNER);
        
        let book = Book {
            title,
            author,
            owner: owner_addr,
            price,
            available: true,
        };
        
        table::add(&mut exchange.books, exchange.next_book_id, book);
        exchange.next_book_id = exchange.next_book_id + 1;
    }

    // Function 2: Buy a book with APT tokens
    public entry fun buy_book(
        buyer: &signer,
        book_id: u64
    ) acquires BookExchange {
        let exchange = borrow_global_mut<BookExchange>(MODULE_OWNER);
        assert!(table::contains(&exchange.books, book_id), E_BOOK_NOT_FOUND);
        
        let book = table::borrow_mut(&mut exchange.books, book_id);
        assert!(book.available, E_BOOK_NOT_AVAILABLE);
        
        // Transfer APT from buyer to seller
        coin::transfer<AptosCoin>(buyer, book.owner, book.price);
        
        // Transfer ownership
        book.owner = signer::address_of(buyer);
        book.available = false;
    }

    // View function: Get book details
    #[view]
    public fun get_book(book_id: u64): (String, String, address, u64, bool) acquires BookExchange {
        let exchange = borrow_global<BookExchange>(MODULE_OWNER);
        assert!(table::contains(&exchange.books, book_id), E_BOOK_NOT_FOUND);
        
        let book = table::borrow(&exchange.books, book_id);
        (book.title, book.author, book.owner, book.price, book.available)
    }
}