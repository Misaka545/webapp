const API_URL = 'http://localhost:3000/api';

function showNotification(message, type = 'info') {
    const noti = document.getElementById('notification');
    noti.className = type === 'info' ? 'notification info' : type === 'success' ? 'notification success' : 'notification error';
    noti.innerHTML = type === 'info' ? `<i class="fas fa-info-circle"></i> ${message}` :
                    type === 'success' ? `<i class="fas fa-check-circle"></i> ${message}` :
                    `<i class="fas fa-exclamation-circle"></i> ${message}`;
    noti.style.display = 'flex';
    setTimeout(() => {
        noti.style.display = 'none';
    }, 3000);
}

function formatMoney(amount) {
    if (isNaN(amount)) return '0';
    return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(amount);
}

async function init() {
    await loadShops();
    renderProductTable();
}

async function loadShops() {
    try {
        const response = await fetch(`${API_URL}/shops`);
        const shops = await response.json();
        const shopSelect = document.getElementById('inputShop');
        const statSelect = document.getElementById('statShopSelect');
        shopSelect.innerHTML = shops.map(shop => `<option value="${shop.ShopID}">${shop.shopName} (${shop.shopStatus})</option>`).join('');
        statSelect.innerHTML = shops.map(shop => `<option value="${shop.ShopID}">${shop.shopName}</option>`).join('');
    } catch (error) {
        console.error('Error loading shops:', error);
    }
}

async function renderProductTable() {
    const keyword = document.getElementById('searchKeyword').value.trim();
    const min = document.getElementById('searchMin').value.trim();
    const max = document.getElementById('searchMax').value.trim();
    try {
        const response = await fetch(`${API_URL}/products?keyword=${encodeURIComponent(keyword)}&min=${min}&max=${max}`);
        const products = await response.json();
        const tableBody = document.getElementById('productTableBody');
        tableBody.innerHTML = " ";

        if (products.length === 0) {
            tableBody.innerHTML = `<tr><td colspan="5" style="text-align: center; padding: 20px; color: var(--text-muted);">Không tìm thấy sản phẩm nào.</td></tr>`;
            return;
        }

        products.forEach(product => {
            const row = document.createElement('tr');
            row.innerHTML = `
                <td><div>${product.productID}</div></td>
                <td>
                    <div>${product.ProductName}</div>
                    <div>${product.Catagory}</div>
                </td>
                <td>${product.ShopName}</td>
                <td>${formatMoney(product.Price)}</td>
            `;
            tableBody.appendChild(row);
        });
    } catch (error) {
        console.error('Error rendering product table:', error);
    }
}



function switchTab(tabName) {
    const tabs = document.querySelectorAll('.tab-content'); 
    const buttons = document.querySelectorAll('.tab-btn');
    tabs.forEach(tab => {
        tab.classList.remove('active');
    });
    buttons.forEach(btn => {
        btn.classList.remove('active');
    }); 
    document.getElementById(`tab-${tabName}`).classList.add('active');
    document.querySelector(`.tab-btn[onclick="switchTab('${tabName}')"]`).classList.add('active');
}
window.onload = init;

