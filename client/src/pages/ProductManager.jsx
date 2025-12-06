import React, { useState, useEffect } from 'react';
import { saveProduct } from '../api/api';

const ProductManager = ({ shops, categories, editData, onCancel, onNotify, onSuccess }) => {
    const [form, setForm] = useState({ shopID: '', categoryID: '', name: '', price: '', desc: '' });

    useEffect(() => {
        if(editData) {
            const foundShop = shops.find(s => s.shopName === editData.ShopName);
            const foundCat = categories.find(c => c.categoryName === editData.Category);

            setForm({ 
                id: editData.productID, 
                shopID: foundShop ? foundShop.shopID : '', 
                categoryID: foundCat ? foundCat.categoryID : '', 
                name: editData.ProductName, 
                price: editData.Price,      
                desc: editData.description 
            });
        }
        else {
            setForm({ shopID: '', categoryID: '', name: '', price: '', desc: '' });
        }
    }, [editData, shops, categories]);

    const submit = async (e) => {
        e.preventDefault();
        const res = await saveProduct({ ...form, basePrice: form.price, description: form.desc });
        if(res.message) { onNotify(res.message); onSuccess(); }
        else onNotify(res.error, 'error');
    };

    return (
        <div className="view-container">
            <div className="top-header">
                <h1>{editData ? `Hiệu chỉnh dữ liệu #${editData.productID}` : 'Khởi tạo dữ liệu mới'}</h1>
                <p className="subtitle">Nhập thông tin chi tiết vào hệ thống</p>
            </div>

            <div className="glass-panel" style={{ maxWidth: 800 }}> 
                <form onSubmit={submit}>
                    <div className="form-grid">
                        <div className="input-group">
                            <label className="input-label"><i className="fas fa-store"></i> Đơn vị cung cấp (Shop)</label>
                            <select 
                                required 
                                className="form-control" 
                                value={form.shopID} 
                                onChange={e=>setForm({...form, shopID:e.target.value})}
                            >
                                <option value="">-- Chọn dữ liệu --</option>
                                {shops.map(s => <option key={s.shopID} value={s.shopID}>{s.shopName}</option>)}
                            </select>
                        </div>

                        <div className="input-group">
                            <label className="input-label"><i className="fas fa-tag"></i> Phân loại (Category)</label>
                            <select 
                                required 
                                className="form-control" 
                                value={form.categoryID} 
                                onChange={e=>setForm({...form, categoryID:e.target.value})}
                            >
                                <option value="">-- Chọn dữ liệu --</option>
                                {categories.map(c => <option key={c.categoryID} value={c.categoryID}>{c.categoryName}</option>)}
                            </select>
                        </div>
                    </div>

                    <div className="form-grid">
                        <div className="input-group">
                            <label className="input-label"><i className="fas fa-box"></i> Tên định danh</label>
                            <input 
                                required 
                                className="form-control" 
                                placeholder="VD: Bàn phím cơ..." 
                                value={form.name} 
                                onChange={e=>setForm({...form, name:e.target.value})} 
                            />
                        </div>

                        <div className="input-group">
                            <label className="input-label"><i className="fas fa-dollar-sign"></i> Đơn giá niêm yết</label>
                            <input 
                                required 
                                type="number" 
                                className="form-control" 
                                placeholder="0" 
                                value={form.price} 
                                onChange={e=>setForm({...form, price:e.target.value})} 
                            />
                        </div>
                    </div>

                    <div className="input-group" style={{marginTop: 24}}>
                        <label className="input-label"><i className="fas fa-align-left"></i> Thông tin chi tiết</label>
                        <textarea 
                            className="form-control" 
                            rows="5" 
                            placeholder="Nhập mô tả kỹ thuật..." 
                            value={form.desc} 
                            onChange={e=>setForm({...form, desc:e.target.value})} 
                            style={{resize:'vertical'}}
                        />
                    </div>
                    
                    <div className="form-actions">
                        {editData && (
                            <button type="button" className="btn btn-ghost" onClick={onCancel}>
                                Hủy bỏ
                            </button>
                        )}
                        <button type="submit" className="btn btn-primary" style={{minWidth: 150}}>
                            <i className="fas fa-save"></i> 
                            {editData ? ' Cập nhật hệ thống' : ' Lưu vào kho dữ liệu'}
                        </button>
                    </div>

                </form>
            </div>
        </div>
    );
};
export default ProductManager;